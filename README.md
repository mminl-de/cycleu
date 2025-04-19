This repository contains two tools. The first is cycleu-lib, which is a zig (and C ABI compatible) library for reading and writing to cycleball.eu
cycleu-cli is a proof of concept that uses cycleu-lib to access and write to cycleball.eu through passing straight forward command line arguments.

# cycleu-lib
`THIS TOOL IS NOT FUNCTIONING, BELOW IS DESCRIBED FEATURES THAT WILL BE HERE SHORTLY`
This library accesses the internal api of cycleball.eu: cycleball.eu/api which the Website (and probably the app) uses as well. It simply returns json for different queries. As the server is quite slow to answer and to avoid load on the servers it provides an "offline version" where all or parts of the data is cached or even scraped and saved for later. It provides all the data in structs and only has ~5 functions. It is written in zig but is C ABI compatible. It is able to read and write but for writing the according PIN is needed

# cycleu-cli
`THIS TOOL IS NOT FUNCTIONING, BELOW IS DESCRIBED FEATURES THAT WILL BE HERE SHORTLY`
This tools allows to access all data available in cycleball.eu through cycleu-lib. It is written in zig and also uses the capability of cycleu-lib to create and use a offline database of all or just a part of the data from cycleball.eu. The main reason for this feature is, that the response times from cycleball.eu is pretty slow (~1-5s)
For now you can only get very specific data like goals of team 1 in game 3 in Matchday 4 from 1. BL, DE not spectrums of data like all games of the 4th Matchday
## Examples
`cycleu-cli read -verband de -staffel b11 -spieltag 2 -spiel 5 -htscore t1`
`cycleu-cli read -verband bb -staffel lln -spieltag 1 -spiel 1 -team t2`
`cycleu-cli read -verband bb -staffel lln -metainfos -staffelleiter -email`
`cycleu-cli read -verband bw -staffel BK_1 -tabelle -platz 3 -teamname`
`cycleu-cli read -verband bw -staffel BK_1 -tabelle -platz 8 -goals_diff`
`cycleu-cli write -pin 123456 -verband de -staffel b11 -spieltag 4 -spiel 2 -score t1 4`
`cycleu-cli write -pin 654321 -verband de -staffel b11 -spieltag 4 -spiel 2 -htscore t2 9`
For details on the possible args see `cycleu-cli --help`

# Why?
We develop [[interscore][github.com/mminl-de/interscore]] a scoreboard and livestream setup for cycleball. The goal is to have easy, high-quality cycleball livestreams for all. For this software we want to integrate cycleball.eu's live results:
1. To access it and calculate live tables and show the audience the course of the other Matchday that is running besides the one we stream. This can be useful for 1./2. BL especially.
2. To automatically write the results of the event to cycleball.eu
