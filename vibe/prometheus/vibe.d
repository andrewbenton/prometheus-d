/*
 * This Source Code Form is subject to the terms of the Mozilla Public License,
 * v. 2.0. If a copy of the MPL was not distributed with this file, You can
 * obtain one at http://mozilla.org/MPL/2.0/.
 */

module prometheus.vibe;

import prometheus.metric;
import prometheus.registry;

import vibe.http.server;

void delegate(HTTPServerRequest, HTTPServerResponse) handleMetrics(Registry reg)
{
    return (HTTPServerRequest, HTTPServerResponse res) {
        ubyte[] data = new ubyte[0];

        foreach(m; reg.metrics)
        {
            data ~= m.collect().encode(EncodingFormat.text);
            data ~= "\n";
        }

        res.writeBody(data, "text/plain");
    };
}
