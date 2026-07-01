# libcycleat
> [!WARNING]
> WIP. The library is working in a proof-of-concept way, but doesnt implement a proper API yet! You can analyze html files directly though. Also see [TODO]

radball.at is still the leading website for all results for cycleball. Every official League and Cup is on there and even some private Cups from Clubs. Until cycleball.eu or upcoming radball.digital are on that level it seems smart to also have a library to grab the results from radball.at. The library uses webscraping because they use a static site generator [LigaManager '98 Free 2.2a][http://www.hollwitz.de/lm98pro.html] and therefor do not use nor provide an API.

The plan for this library is to expose a very similar or equal API to libcycleu. It will also be C/C++ ABI compatible.

## Usage
1. Download all html sites from current homepage with `radballat.sh`
2. Use `libcycleat.zig` to analyze files or directories into Leagues.

## TODO
[ ] support older years through official [archive][https://www.vfh-muecheln.de/ergebnisse2025.htm] and support older formats
[ ] implement scraping (radballat.sh) in zig
    [ ] scrape only parts, scrape league names first, expose this with API
    [ ] More intelligent grouping of leagues (years, countries, categories), exposed as API
[ ] scrape more 
    [ ] Gym
    [ ] Player Names
    [ ] League Metadata: Ruletext, Amount promoted/demoted Teams
[ ] Intelligent Matchday formatting through gameday table and dates?
[ ] use less allocations
[ ] check for memory leaks when not using Arenas
[ ] Write C header
## Not Supported
- [Custom Tournament Sites][https://www.vfh-muecheln.de/2024/Ergebnisse/WorldCup/Hannover_2024.htm] are not supported, because they are too complicated
