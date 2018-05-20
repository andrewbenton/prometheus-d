module prometheus.gauge;

import prometheus.metric;

import std.exception : enforce;

version(unittest)
    import fluent.asserts;

class Gauge : Metric
{
    private double[string[]] values;

    this(string name, string help, string[] labels)
    {
        this.name = name;
        this.help = help;
        this.labels = labels.dup;

        //if there are no labels, then the value defaults to zero.
        if(labels is null || labels.length == 0)
            this.values[(string[]).init.idup] = 0;
    }

    override void observe(double value, string[] labelValues)
    {
        enforce(this.labels.length == labelValues.length);

        if(labelValues in this.values)
            this.values[labelValues.idup] += value;
        else
            this.values[labelValues.idup] = value;
    }

    void inc(double value = 1, string[] labelValues = [])
    {
        this.observe(value, labelValues);
    }

    void dec(double value = 1, string[] labelValues = [])
    {
        this.observe(-value, labelValues);
    }

    void set(double value, string[] labelValues = [])
    {
        enforce(this.labels.length == labelValues.length);

        this.values[labelValues.idup] = value;
    }

    void setToCurrentTime(string[] labelValues = [])
    {
        this.set(Metric.posixTime / 1000.0, labelValues);
    }

    override MetricSnapshot collect()
    {
        return new GaugeSnapshot(this);
    }
}

private class GaugeSnapshot : MetricSnapshot
{
    import prometheus.encoding;

    string name;
    string help;
    string[] labels;
    double[string[]] values;
    long timestamp;

    this(Gauge g)
    {
        this.name = g.name;
        this.help = g.help;
        this.labels = g.labels;
        foreach(k,v; g.values)
            this.values[k.idup] = v;

        this.timestamp = Metric.posixTime;
    }

    override ubyte[] encode(EncodingFormat fmt = EncodingFormat.text)
    {
        enforce(fmt == EncodingFormat.text, "Unsupported encoding type");

        import std.array : appender, Appender;
        import std.format : format;
        import std.string : empty;

        Appender!string output = appender!string;

        if(!this.help.empty)
            output ~= TextEncoding.encodeHelp(this.name, this.help);

        output ~= TextEncoding.encodeType(this.name, "gauge");

        foreach(labelValues, value; this.values)
            output ~= TextEncoding.encodeMetricLine(
                this.name,
                this.labels,
                labelValues,
                value,
                this.timestamp);

        return cast(ubyte[])output.data;
    }
}
