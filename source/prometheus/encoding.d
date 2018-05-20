module prometheus.encoding;

import std.format : format;
import std.functional : pipe;

version(unittest)
    import fluent.asserts;

class TextEncoding
{
    import std.string : replace;

    alias encodeKey = pipe!(
        (string s) { return replace(s, `\`, `\\`); },
        (string s) { return replace(s, "\n", `\n`); },
    );

    static string encodeType(string name, string type)
    {
        return "# TYPE %s %s\n".format(encodeKey(name), type);
    }

    static string encodeHelp(string name, string help)
    {
        return "# HELP %s %s\n".format(encodeKey(name), encodeKey(help));
    }

    alias encodeLabelValue = pipe!(
        encodeKey,
        (string s) { return replace(s, `"`, `\"`); }
    );

    static string encodeNumber(double value)
    {
        import std.format : format;
        import std.math : isInfinity, isNaN, sgn;
        import std.string : strip, stripRight;

        if(value.isNaN)
            return "Nan";
        if(value.isInfinity)
            return value.sgn > 0 ? "+Inf" : "-Inf";

        return "%f".format(value).strip("0").stripRight(".");
    }

    unittest
    {
        //usual cases
        encodeNumber(1.0).should.equal("1");
        encodeNumber(1.1).should.equal("1.1");
        encodeNumber(-1.1).should.equal("-1.1");
        encodeNumber(1000000000.1234).should.equal("1000000000.1234");
        encodeNumber(-00000000.12348).should.equal("-0.12348");

        //unusual cases
        encodeNumber(float.infinity).should.equal("+Inf");
        encodeNumber(-float.infinity).should.equal("-Inf");
        encodeNumber(float.nan).should.equal("Nan");
    }

    static string encodeLabels(const string[] labels, const string[] labelValues)
    {
        if(labels is null || labels.length < 1)
            return "";
        else
        {
            import std.algorithm.iteration : map;
            import std.format : format;
            import std.range : zip;

            return "{%-(%s,%)}".format(zip(labels, labelValues).
                map!(t => "%s=\"%s\"".format(
                    TextEncoding.encodeKey(t[0]),
                    TextEncoding.encodeLabelValue(t[1])
                )
            ));
        }
    }

    unittest
    {
        encodeLabels([], []).should.equal("");
        encodeLabels(["a"], ["b"]).should.equal("{a=\"b\"}");
    }

    static string encodeMetricLine(const string name, const string[] labels, const string[] labelValues, double value, long timestamp)
    {
        import std.format : format;

        return "%s%s %s %d\n".format(
            encodeKey(name),
            encodeLabels(labels, labelValues),
            encodeNumber(value),
            timestamp
        );
    }
}
