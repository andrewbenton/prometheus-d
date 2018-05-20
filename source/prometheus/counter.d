/*
 * This Source Code Form is subject to the terms of the Mozilla Public License,
 * v. 2.0. If a copy of the MPL was not distributed with this file, You can
 * obtain one at http://mozilla.org/MPL/2.0/.
 */

module prometheus.counter;

import prometheus.metric;

import std.exception : enforce;

version(unittest)
    import fluent.asserts;

class Counter : Metric
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

    void inc(double value = 1, string[] labels = [])
    {
        this.observe(value, labels);
    }

    override void observe(double value, string[] labelValues)
    {
        import std.math : fmax;

        enforce(this.labels.length == labelValues.length);

        //counter is monotonically increasing
        value = fmax(value, 0);

        if(labelValues in this.values)
            this.values[labelValues.idup] += value;
        else
            this.values[labelValues.idup] = value;
    }

    override MetricSnapshot collect()
    {
        return new CounterSnapshot(this);
    }
}

unittest
{
    Counter c = new Counter("test", "testing counter w/ no labels", []);
    c.inc();
    c.observe(1, []);
}

private class CounterSnapshot : MetricSnapshot
{
    import prometheus.encoding;

    string name;
    string help;
    string[] labels;
    double[string[]] values;
    long timestamp;

    this(Counter c)
    {
        this.name = c.name;
        this.help = c.help;
        this.labels = c.labels;
        foreach(k, v; c.values)
            this.values[k.idup] = v;

        this.timestamp = Metric.posixTime;
    }

    override ubyte[] encode(EncodingFormat fmt = EncodingFormat.text)
    {
        enforce(fmt == EncodingFormat.text, "Unsupported encoding type");

        import std.array : appender, Appender;
        import std.string : empty;

        Appender!string output = appender!string;

        if(!this.help.empty)
            output ~= TextEncoding.encodeHelp(this.name, this.help);

        output ~= TextEncoding.encodeType(this.name, "counter");

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

unittest
{
    Counter c = new Counter("test", "counter w/ no labels", []);
    c.inc().should.not.throwAnyException;
}

unittest
{
    Counter c = new Counter("test", "counter w/ a label", ["domain"]);
    c.inc().should.throwSomething;
}

unittest
{
    import std.conv : to;
    import std.stdio : writeln;

    Counter c = new Counter("test", "counter snapshot w/ no labels", []);
    c.inc();
    c.inc();
    c.observe(3, []);

    MetricSnapshot shot = c.collect;

    ubyte[] data = shot.encode(EncodingFormat.text);

    `\\\`.writeln;
    (cast(string)data).writeln;
    "///".writeln;
}

unittest
{
    import std.conv : to;
    import std.stdio : writeln;

    Counter c = new Counter("test", "counter snapshot w/ labels", ["domain"]);
    c.inc(1, ["domain.com"]);
    c.inc(2, ["domain.org"]);
    c.observe(10, ["domain.net"]);

    MetricSnapshot shot = c.collect;

    ubyte[] data = shot.encode(EncodingFormat.text);

    `\\\`.writeln;
    (cast(string)data).writeln;
    "///".writeln;
}
