module prometheus.registry;

import prometheus.metric;

version (unittest) import fluent.asserts;

@safe:

class Registry
{
    private __gshared Registry instance;

    static Registry global() @system
    {
        import std.concurrency : initOnce;

        return initOnce!instance(new Registry);
    }

    private Metric[Metric] _metrics;

    this()
    {
    }

    void register(Metric m)
    {
        synchronized (this)
        {
            this._metrics[m] = m;
        }
    }

    void unregister(Metric m)
    {
        synchronized (this)
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

@system unittest
{
    // given
    alias UnderTest = Registry;

    // when
    auto registry = UnderTest.global;

    // then
    registry.should.not.equal(null);
}

@system unittest
{
    // given
    alias UnderTest = Registry;
    auto registry1 = UnderTest.global;

    // when
    auto registry2 = UnderTest.global;

    // then
    registry2.should.equal(registry1);
}
