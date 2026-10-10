# Genuine schema 10 fixture

The unmodified Core at `272183b` produced this localOnly store through public commands. The producer creates shared labels, a List, a labelled Item with one owned link, a membership, global completion, a List archive state and a timed start-only Schedule. Its acknowledged checkpoint is 8.

`Producer.swift.txt` records the exact public journey. `manifest.json` records source identities, timestamps, field hashes and acknowledged portable bytes. `checksums.json` records the captured files. The producer initially attempted to read the internal session epoch; removing that inaccessible property allowed its one runtime function to pass. No internal store API produced this fixture.

Migration tests copy the fixture before opening it. Share must require the main app to migrate. Main-app migration preserves the graph and old recovery bytes, then accepts a new Itinerary with shared labels and owned links.
