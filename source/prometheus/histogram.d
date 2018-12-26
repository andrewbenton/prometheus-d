/*
 * This Source Code Form is subject to the terms of the Mozilla Public License,
 * v. 2.0. If a copy of the MPL was not distributed with this file, You can
 * obtain one at http://mozilla.org/MPL/2.0/.
 */

module prometheus.histogram;

import prometheus.metric;

version(PrometheusUnittest)
    import fluent.asserts;

class Histogram : Metric
{
    private double[] bucketValues;
    private HistogramBucket[string[]] buckets;

    this(string name, string help, string[] labels, double[] buckets)
    {
        this.name = name;
        this.help = help;
        this.labels = labels.dup;
        this.bucketValues = buckets.dup;

        if(labels is null || labels.length == 0)
            this.buckets[(string[]).init.idup] = HistogramBucket(this);
    }

    override void observe(double value, string[] labelValues = null)
    {
        import std.exception : enforce;

        enforce(labelValues.length == this.labels.length);

        auto indexValue = labelValues.idup;

        if(!(labelValues in this.buckets))
            this.buckets[indexValue] = HistogramBucket(this);

        this.buckets[indexValue].observe(value);
    }

    override MetricSnapshot collect()
    {
        return new HistogramSnapshot(this);
    }
}

//test lifecycle w/ no labels
unittest
{
    auto h = new Histogram("test", "testing description", null, Buckets.linear(0, 1, 5));

    h.observe(-1).should.not.throwAnyException;
    h.observe( 0).should.not.throwAnyException;
    h.observe( 1).should.not.throwAnyException;
    h.observe( 2).should.not.throwAnyException;
    h.observe( 3).should.not.throwAnyException;
    h.observe( 4).should.not.throwAnyException;
    h.observe( 5).should.not.throwAnyException;
    h.observe( 6).should.not.throwAnyException;

    h.collect.encode.should.not.throwAnyException;
}

//test lifecycle w/ labels
unittest
{
    auto h = new Histogram("test", "test w/ labels", ["verb"], Buckets.linear(0, 1, 2));

    foreach(verb; ["get", "set"])
        for(int i = -1; i < 5; i++)
            h.observe(i, [verb]).should.not.throwAnyException;

    h.collect.encode.should.not.throwAnyException;
}

struct HistogramBucket
{
    private Histogram parent;
    private double[] values;
    private double sum;

    this(Histogram parent)
    {
        this.sum = 0;
        this.parent = parent;
        this.values = new double[this.parent.bucketValues.length + 1];
        for(int i = 0; i < this.values.length; i++)
            this.values[i] = 0;
    }

    void observe(double value)
    {
        this.sum += value;

        this.values[this.values.length-1]++; // inf bucket

        for(long i = this.values.length - 2; i > -1; i--)
        {
            if(value > this.parent.bucketValues[i])
                break;

            this.values[i]++;
        }
    }

    HistogramBucket dup()
    {
        auto ret = HistogramBucket(this.parent);
        ret.sum = 0;
        ret.values = this.values.dup;
        return ret;
    }
}

final class Buckets
{
    static double[] linear(double start, double width, long count)
    {
        double[] ret = new double[count-1];
        for(int i = 0; i < count - 1; i++)
        {
            ret[i] = start + (width * i);
        }
        return ret;
    }

    static double[] exponential(double start, double factor, long count)
    {
        import std.math : pow;

        double[] ret = new double[count-1];
        for(int i = 0; i < count - 1; i++)
        {
            ret[i] = start * pow(factor, i);
        }
        return ret;
    }
}

//test linear
unittest
{
    auto lin1 = Buckets.linear(0, 1, 4);
    lin1.length.should.equal(3);
    lin1[0].should.equal(0);
    lin1[1].should.equal(1);
    lin1[2].should.equal(2);

    auto lin2 = Buckets.linear(-1, 1, 5);
    lin2.length.should.equal(4);
    lin2[0].should.equal(-1);
    lin2[1].should.equal(0);
    lin2[2].should.equal(1);
    lin2[3].should.equal(2);
}

//test exponential

private class HistogramSnapshot : MetricSnapshot
{
    import prometheus.encoding;

    import std.array : appender, Appender;

    string name;
    string help;
    string[] labels;
    double[] bucketValues;
    HistogramBucket[string[]] buckets;
    long timestamp;

    this(Histogram h)
    {
        this.name = h.name;
        this.help = h.help;
        this.labels = h.labels;
        this.bucketValues = h.bucketValues;

        foreach(k, v; h.buckets)
            this.buckets[k] = v.dup;

        this.timestamp = Metric.posixTime;
    }

    override ubyte[] encode(EncodingFormat fmt = EncodingFormat.text)
    {
        import std.exception : enforce;
        import std.string : empty;

        Appender!string output = appender!string;

        if(!this.help.empty)
            output ~= TextEncoding.encodeHelp(this.name, this.help);

        output ~= TextEncoding.encodeType(this.name, "counter");

        foreach(labelValues, value; this.buckets)
            this.writeBucket(output, labelValues, value);

        return cast(ubyte[])output.data;
    }

    private void writeBucket(ref Appender!string output, const ref string[] labelValues, const ref HistogramBucket bucket)
    {
        for(int i = 0; i < bucket.values.length; i++)
        {
            output ~= TextEncoding.encodeMetricLine(
                this.name ~ "_bucket",
                this.labels ~ "le",
                labelValues ~ this.bucketValueString(i),
                bucket.values[i],
                this.timestamp);
        }

        output ~= TextEncoding.encodeMetricLine(
            this.name ~ "_sum",
            this.labels,
            labelValues,
            bucket.sum,
            this.timestamp);

        output ~= TextEncoding.encodeMetricLine(
            this.name ~ "_count",
            this.labels,
            labelValues,
            bucket.values[bucket.values.length-1],
            this.timestamp);
    }

    private string bucketValueString(int idx)
    {
        return TextEncoding.encodeNumber(
            idx < this.bucketValues.length ?
                this.bucketValues[idx] :
                double.infinity
        );
    }
}
