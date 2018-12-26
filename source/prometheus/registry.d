module prometheus.registry;

import prometheus.metric;

@safe:

class Registry
{
    private __gshared Registry instance;

    shared static this() @system
    {
        Registry.instance = new Registry;
    }

    static Registry global() @system { return Registry.instance; }

    private Metric[Metric] _metrics;

    this()
    {
    }

    void register(Metric m)
    {
        synchronized(this)
        {
            this._metrics[m] = m;
        }
    }

    void unregister(Metric m)
    {
        synchronized(this)
        {
            this._metrics.remove(m);
        }
    }

    @property Metric[] metrics()
    {
        import std.array : array;
        return this._metrics.byValue.array;
    }
}
