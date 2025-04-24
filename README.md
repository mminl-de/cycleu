# cycleu
This repository contains **libcycleu**, a C ABI compatible library written in Zig that reads and writes from [cycleball.eu](https://cycleball.eu) and **cycleu**, a CLI frontend over the library. The latter is a proof-of-concept tool that uses straightforward command line arguments to leverage the library.

## libcycleu
> [!WARNING]
> Work In Progress. All read functions should work. Though not all edge cases have been tested. Be aware that sometimes not all data in the structs are present! Offline mode and Writing is not implemented yet!

This library accesses the internal API of [cycleball.eu/api](https://cycleball.eu/api), which the website (and probably the app) use as well. It simply returns JSON for different queries. As the server is quite slow to answer and to avoid load on the servers it provides an "offline version" where all or parts of the data are cached and saved for later. In order to write to the website, the write key is needed as in the official app and website.<br>
It provides all the data in structs and only has ~5 public functions.<br>
Although the library is written in Zig, it is C ABI compatible and thus can be used from C/C++ like any other library.

### Installation
TODO

### Examples
TODO

### State
- cycleu_fetch_association
    - [x] working 
    - [ ] feature complete (json to struct support)
        - [ ] name_short
        - [ ] name_long
    - [x] not leaking
- cycleu_fetch_league
    - [x] working
    - [ ] feature complete (json to struct support)
        - [ ] last_update
    - [x] not leaking
- cycleu_fetch_matchday
    - [x] working
    - [ ] feature complete (json to struct support)
        - [ ] teams[].lastImport
        - [ ] incidents
    - [ ] not leaking
- cycleu_fetch_club
    - [ ] working
    - [ ] feature complete (json to struct support)
    - [ ] not leaking
- cycleu_write_result
    - [ ] working
    - [ ] feature complete (json to struct support)
    - [ ] not leaking
#### TODO
- fix memory leaks in fetch_matchday
- write convertion function from json timestamp to time_t
- support offline cache
- Find API for associations
- add recursive modes
- fetch league if no league is provided in fetch_matchday for orig_team

## cycleu
> [!WARNING]
> Work In Progress. This is not yet working!

This tools allows to access all data available in cycleball.eu through cycleu-lib. It is written in zig and also uses the capability of cycleu-lib to create and use a offline database of all or just a part of the data from cycleball.eu. The main reason for this feature is, that the response times from cycleball.eu is pretty slow (~1-3s)
For now you can only get very specific data like goals of team 1 in game 3 in Matchday 4 from 1. BL, DE not spectrums of data like all games of the 4th Matchday

### Usage
```
cycleu read -verband de -staffel b11 -spieltag 2 -spiel 5 -htscore t1
cycleu read -verband bb -staffel lln -spieltag 1 -spiel 1 -team t2
cycleu read -verband bb -staffel lln -metainfos -staffelleiter -email
cycleu read -verband bw -staffel BK_1 -tabelle -platz 3 -teamname
cycleu read -verband bw -staffel BK_1 -tabelle -platz 8 -goals_diff
cycleu write -pin 123456 -verband de -staffel b11 -spieltag 4 -spiel 2 -score t1 4
cycleu write -pin 654321 -verband de -staffel b11 -spieltag 4 -spiel 2 -htscore t2 9
```

See also `cycleu --help`.

### Why?
We developed [Interscore](https://github.com/mminl-de/interscore), a scoreboard and livestream setup for Cycleball. The goal is to provide easy, high-quality Cycleball livestreams for everyone. For this software we want to integrate cycleball.eu's live results:

1. To access them, calculate live tables and show the audience the course of the other matchday that is running besides the one we stream. This can be especially useful for the 1st and 2nd Bundesliga.
2. To automatically write the results of the event to cycleball.eu.

