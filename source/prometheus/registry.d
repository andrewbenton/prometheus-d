module prometheus.registry;

import prometheus.metric;

class Registry
{
    private __gshared Registry instance;

    shared static this()
    {
        Registry.instance = new Registry;
    }

    static Registry global() { return Registry.instance; }

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
        return this._metrics.values;
    }
}
