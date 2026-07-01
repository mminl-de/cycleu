# cycleu
This repository contains **libcycleu** and **libcycleat**, both C ABI compatible libraries written in Zig that read (and libcycleu also writes) from [cycleball.eu](https://cycleball.eu)/[radball.at](https://https://www.vfh-muecheln.de/Radball.at/Vorschau2.htm).

## Why?
We develop [Interscore](https://github.com/mminl-de/interscore), a scoreboard and livestream setup for Cycleball. The goal is to provide easy, high-quality Cycleball livestreams for everyone. For this software we want to integrate cycleball.eu's live results and access Matchday information from radball.at/cycleball.eu:

1. To access them, calculate live tables and show the audience the course of the other matchday that is running besides the one we stream. This can be especially useful for the 1st and 2nd Bundesliga.
2. To automatically write the results of the event to cycleball.eu.
3. Load a Matchday directly from cycleball.eu/radball.at instead of creating it tediously by hand

See the README.md's in the subdirectories for more information on each library and their current state.
