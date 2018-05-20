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
