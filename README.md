Prometheus for D
================

This library helps you expose your metrics in a [Prometheus][prometheus] compatible format.  The core library has no external dependencies which makes it easy to integrate with other solutions.

Example
-------

This is an example using [Vibe.d][vibe] to export the number of page hits.

```d
import prometheus.counter;
import prometheus.registry;
import prometheus.vibe;

import vibe.d;

void main()
{
    auto settings = new HTTPServerSettings;
    settings.port = 10000;

    //create counter and register with global registry
    Counter c = new Counter("hit_count", "Shows the number of site hits", null);
    c.register;

    //start routes for Vibe.d
    auto router = new URLRouter;
    router.any("*", (HTTPServerRequest req, HTTPServerResponse res) {
        c.inc;
    });
    router.get("/", (HTTPServerRequest req, HTTPServerResponse res) {
        res.writeBody(cast(ubyte[])"hello, world!");
    });
    router.get("/metrics", handleMetrics(Registry.global));

    listenHTTP(settings, router);
    runApplication;
}
```

TODO
---------

- [x] Counter
- [x] Gauge
- [x] Histogram
- [ ] Summary
- [ ] Default Dlang metrics (GC, etc...)
- [x] [Vibe.d][vibe] integration
- [ ] [Hunt][hunt] integration


[prometheus]: https://prometheus.io/
[vibe]: https://github.com/vibe-d/vibe.d
[hunt]: https://github.com/huntlabs/hunt
