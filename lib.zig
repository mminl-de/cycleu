//! libcycleu – read and write game results from/to cycleball.eu

const builtin = @import("builtin");
const std = @import("std");
const c = @cImport(@cInclude("curl/curl.h"));

// TODO BEGIN TEST
const AllocatorType = enum(u8) { c, testing };

// TODO const allocator = if (builtin.is_test) std.testing.allocator else std.heap.c_allocator;
const allocator = if (builtin.is_test and @import("tests").allocator != .c)
    std.testing.allocator
    else std.heap.c_allocator;


const char_ptr = [*:0]const u8;
const void_ptr = ?*anyopaque;
const time_t = i64;

const print = std.debug.print;


//TODO Reverse engineer API for getting all available Associations
const AssociationType = enum(u8) { Deutschland, Bayern, Brandenburg, BadenWuerttemberg, Hessen, RheinlandPfalz };
const FetchStatus = enum(u8) { Ok, AuthCodeWrong, LeagueUnknown, GameUnknown, Internet, CURL, OutOfMemory, JSONMisformated, Unknown };
const URLProtocol = enum(u8) { HTTPS, HTTP, FILE };

const ASSOCIATION_CODES = [_]*const [2:0]u8{ "de", "by", "bb", "bw", "he", "rp" };
const URL_BASE = "cycleball.eu/api";
const URL_PROTOCOLS = [_][]const u8{ "https://", "http://", "file://" }; // TODO CONSIDER file://

var curl: ?*c.CURL = null;

const Association = extern struct {
    name_short: char_ptr,
    name_long: char_ptr,
    leagues: [*]League,
    league_n: u32,
    clubs: [*]const Club,
    club_n: u32,

    fn deinit(self: *const Association) void {
        for (self.leagues[0..self.league_n]) |league| league.deinit();
        allocator.free(self.leagues[0..self.league_n]);

        for (self.clubs[0..self.club_n]) |club| club.deinit();
        allocator.free(self.clubs[0..self.club_n]);
    }
};

const League = extern struct {
    name_short: char_ptr,
    name_long: char_ptr,
    competitive: bool,
    season: u16,
    manager: extern struct {
        name: char_ptr,
        email: char_ptr,
        phone: char_ptr,
        address: extern struct {
            city: char_ptr,
            zip: u32,
            street: char_ptr
        }
    },
    matchdays: [*] const Matchday,
    matchday_n: u8,
    teams: [*]const Team,
    team_n: u8,
    ranks: [*]const Rank,
    rank_n: u8,
    rules: [*]const char_ptr,
    rule_n: u8,
    last_update: time_t,

    // TODO IFPOSSIBLE make fewer allocations and frees
    fn deinit(self: *const League) void {
        allocator.free(std.mem.span(self.name_short));
        allocator.free(std.mem.span(self.name_long));

        allocator.free(std.mem.span(self.manager.name));
        allocator.free(std.mem.span(self.manager.email));
        allocator.free(std.mem.span(self.manager.phone));
        allocator.free(std.mem.span(self.manager.address.city));
        allocator.free(std.mem.span(self.manager.address.street));

        for (self.matchdays[0..self.matchday_n]) |md| md.deinit();
        for (self.rules[0..self.rule_n]) |rule| allocator.free(std.mem.span(rule));
        for (self.teams[0..self.team_n]) |team| team.deinit();

        allocator.free(self.ranks[0..self.rank_n]);
        allocator.free(self.teams[0..self.team_n]);
        allocator.free(self.rules[0..self.rule_n]);
        allocator.free(self.matchdays[0..self.matchday_n]);
    }
};

// NOTE This is only used in League. The outside def. is needed to fetch its size with malloc
const Rank = extern struct {
    team: *const Team,
    games_amount: u8,
    goals_plus: u16,
    goals_minus: u16,
    points: u16,
    rank: u8
};

const Matchday = extern struct {
    number: u8,
    start: time_t,
    gym: Gym,
    host_club_name: char_ptr,
    teams: [*]const Matchday_Team,
    team_n: u8,
    games: [*]const Game,
    game_n: u8,

    //TODO how do incidents work? We need an example
    fn deinit(self: *const Matchday) void {
        self.gym.deinit();

        allocator.free(std.mem.span(self.host_club_name));

        for (self.teams[0..self.team_n]) |team| team.deinit();
        allocator.free(self.teams[0..self.team_n]);

        allocator.free(self.games[0..self.game_n]);
    }
};

const Matchday_Team = extern struct {
    name: char_ptr,
    present: bool,
    players: [*]const Matchday_Player,
    player_n: u8,

    fn deinit(self: *const Matchday_Team) void {
        for (self.players[0..self.player_n]) |player| player.deinit();
        allocator.free(self.players[0..self.player_n]);
        allocator.free(std.mem.span(self.name));
    }
};

const Matchday_Player = extern struct {
    player: Player,
    regular: bool,

    fn deinit(self: *const Matchday_Player) void {
        self.player.deinit();
    }
};

const Game = extern struct {
    number: u8,
    team_a: *const Matchday_Team,
    team_b: *const Matchday_Team,
    // -1 means unknown
    goals: extern struct {
        a: i8,
        b: i8,
        half: extern struct { a: i8, b: i8 } 
    },
    is_writable: bool,

    // No `deinit` function bc nothing is allocated
};

const Team = extern struct {
    club_name: char_ptr,
    name: char_ptr,
    players: [*]const Player,
    player_n: u8,

    fn deinit(self: *const Team) void {
        for (self.players[0..self.player_n]) |player| player.deinit();
        allocator.free(self.players[0..self.player_n]);
        allocator.free(std.mem.span(self.club_name));
        allocator.free(std.mem.span(self.name));
    }
};

const Player = extern struct {
    name: char_ptr,
    uci_code: char_ptr,

    fn deinit(self: *const Player) void {
        allocator.free(std.mem.span(self.name));
        allocator.free(std.mem.span(self.uci_code));
    }
};

const Club = extern struct {
    name: char_ptr,
    city: char_ptr,
    contact: extern struct {
        name: char_ptr,
        email: char_ptr,
        phone: char_ptr,
        address: extern struct {
            city: char_ptr,
            zip: u32,
            street: char_ptr
        }
    },
    gyms: [*]const Gym,
    gym_n: u8,

    fn deinit(self: *const Club) void {
        allocator.free(std.mem.span(self.name));
        allocator.free(std.mem.span(self.city));

        allocator.free(std.mem.span(self.contact.name));
        allocator.free(std.mem.span(self.contact.email));
        allocator.free(std.mem.span(self.contact.phone));
        allocator.free(std.mem.span(self.contact.address.city));
        allocator.free(std.mem.span(self.contact.address.street));

        for (self.gyms[0..self.gym_n]) |gym| gym.deinit();
        allocator.free(self.gyms[0..self.gym_n]);
    }
};

const Gym = extern struct {
    name: char_ptr,
    phone: char_ptr,
    address: extern struct {
        city: char_ptr,
        zip: u32,
        street: char_ptr
    },

    fn deinit(self: *const Gym) void {
        allocator.free(std.mem.span(self.name));
        allocator.free(std.mem.span(self.phone));
        allocator.free(std.mem.span(self.address.city));
        allocator.free(std.mem.span(self.address.street));
    }
};

export fn cycleu_init() callconv(.C) bool {
    _ = c.curl_global_init(c.CURL_GLOBAL_ALL);
    curl = c.curl_easy_init() orelse {
        print("ERROR: cURL is striking. Come back tomorrow!\n", .{});
        return false;
    };

    _ = c.curl_easy_setopt(curl, c.CURLOPT_FOLLOWLOCATION, @as(u8, 1));
    _ = c.curl_easy_setopt(curl, c.CURLOPT_USERAGENT, "curl/8.13.0");
    _ = c.curl_easy_setopt(curl, c.CURLOPT_WRITEFUNCTION, receive_json);
    //_ = c.curl_easy_setopt(curl, c.CURLOPT_VERBOSE, @as(u8, 1));

    return true;
}

export fn cycleu_fetch_association(
    association: *Association,
    association_code: AssociationType,
    recursive: bool,
) callconv(.C) FetchStatus {
    if (curl == null) return FetchStatus.CURL;

    const url =
        URL_PROTOCOLS[@intFromEnum(URLProtocol.HTTPS)] ++ 
        ASSOCIATION_CODES[@intFromEnum(association_code)] ++ 
        "." ++ URL_BASE;
    const url_leagues = url ++ "/leagues";
    const url_clubs = url ++ "/clubs";

    var json_leagues: []u8 = undefined;
    var ret_val = fetch_url(url_leagues, &json_leagues);
    if (ret_val != FetchStatus.Ok) {
        print("failed to fetch association leagues {s} :(", .{@tagName(ret_val)});
        return ret_val;
    }
    defer allocator.free(json_leagues);

    //print("SUCCESS: Received Association League (FETCH_ASSOCIATION):\n{s}\n", .{json_leagues});

    var json_clubs: []u8 = undefined;
    ret_val = fetch_url(url_clubs, &json_clubs);
    if (ret_val != FetchStatus.Ok) {
        print("failed to fetch association clubs {s} :(", .{@tagName(ret_val)});
        return ret_val;
    }
    defer allocator.free(json_clubs);

    print("SUCCESS: Received Association clubs:\n", .{});

    const _League = struct {
        shortName: []const u8,
        longName: []const u8,
        hasNonCompetitive: bool,
        season: []const u8,
        manager: struct {
            name: []const u8,
            email: []const u8,
            street: []const u8,
            zip: []const u8,
            city: []const u8,
            phone: []const u8
        },
        rules: [][]const u8,
        lastImport: []const u8
    };

    const leagues_parsed = std.json.parseFromSlice([]_League, allocator, json_leagues, .{.ignore_unknown_fields = true}) catch |err| {
        print("JSON for Association leagues are wrong format: {s}\n", .{@errorName(err)});
        return FetchStatus.JSONMisformated;
    };
    defer leagues_parsed.deinit();

    var leagues = allocator.alloc(League, leagues_parsed.value.len) catch return FetchStatus.OutOfMemory;
    for (0.., leagues_parsed.value) |i, league_parsed| {
        const zipval: u32 = std.fmt.parseInt(u32, league_parsed.manager.zip, 10) catch 0;
        leagues[i] = .{
            .name_short = slice_deepcopy_to_charptr(league_parsed.shortName) catch return FetchStatus.OutOfMemory,
            .name_long = slice_deepcopy_to_charptr(league_parsed.longName) catch return FetchStatus.OutOfMemory,
            .competitive = !league_parsed.hasNonCompetitive,
            .season = std.fmt.parseInt(u16, league_parsed.season, 10) catch return FetchStatus.JSONMisformated,
            .manager = .{
                .name = slice_deepcopy_to_charptr(league_parsed.manager.name) catch return FetchStatus.OutOfMemory,
                .email = slice_deepcopy_to_charptr(league_parsed.manager.email) catch return FetchStatus.OutOfMemory,
                .phone = slice_deepcopy_to_charptr(league_parsed.manager.phone) catch return FetchStatus.OutOfMemory,
                .address = .{
                    .city = slice_deepcopy_to_charptr(league_parsed.manager.city) catch return FetchStatus.OutOfMemory,
                    .zip = zipval,
                    .street = slice_deepcopy_to_charptr(league_parsed.manager.street) catch return FetchStatus.OutOfMemory 
                },
            },
            .matchdays = undefined,
            .matchday_n = 0,
            .teams = undefined,
            .team_n = 0,
            .ranks = undefined,
            .rank_n = 0,
            .rules = slice_array_deepcopy_to_charptr(league_parsed.rules) catch return FetchStatus.OutOfMemory,
            .rule_n = @intCast(league_parsed.rules.len),
            .last_update = 0
            // TODO .last_update = league_parsed.lastImport
        };
        if(recursive) {
            ret_val = cycleu_fetch_league(&leagues[i], association_code, leagues[i].name_short, true, recursive);
            if (ret_val != FetchStatus.Ok)
                return ret_val;
        }
    }

    const _Club = struct {
        name: []const u8,
        city: []const u8,
        contact: struct {
            name: []const u8,
            email: []const u8,
            street: []const u8,
            zip: []const u8,
            city: []const u8,
            phone: []const u8
        },
        gyms: []struct {
            name: []const u8,
            street: []const u8,
            zip: []const u8,
            city: []const u8,
            phone: []const u8
        }
    };

    const clubs_parsed = std.json.parseFromSlice([]_Club, allocator, json_clubs, .{.ignore_unknown_fields = true}) catch |err| {
        print("JSON for Association Clubs are wrong format: {s}\n", .{@errorName(err)});
        return FetchStatus.JSONMisformated;
    };
    defer clubs_parsed.deinit();

    var clubs = allocator.alloc(Club, clubs_parsed.value.len) catch return FetchStatus.OutOfMemory;
    for (clubs_parsed.value, 0..) |club_parsed, i| {
        const zipval: u32 = std.fmt.parseInt(u32, club_parsed.contact.zip, 10) catch 0;

        const gyms = allocator.alloc(Gym, club_parsed.gyms.len) catch return FetchStatus.OutOfMemory;
        for (club_parsed.gyms, 0..) |gym, j| {
            const gym_zipval: u32 = std.fmt.parseInt(u32, gym.zip, 10) catch 0;
            gyms[j] = .{
                .name = slice_deepcopy_to_charptr(gym.name) catch return FetchStatus.OutOfMemory,
                .phone = slice_deepcopy_to_charptr(gym.phone) catch return FetchStatus.OutOfMemory,
                .address = .{
                    .city = slice_deepcopy_to_charptr(gym.city) catch return FetchStatus.OutOfMemory,
                    .zip = gym_zipval,
                    .street = slice_deepcopy_to_charptr(gym.street) catch return FetchStatus.OutOfMemory
                }
            };
        }

        clubs[i] = .{
            .name = slice_deepcopy_to_charptr(club_parsed.name) catch return FetchStatus.OutOfMemory,
            .city = slice_deepcopy_to_charptr(club_parsed.city) catch return FetchStatus.OutOfMemory,
            .contact = .{
                .name = slice_deepcopy_to_charptr(club_parsed.contact.name) catch return FetchStatus.OutOfMemory,
                .email = slice_deepcopy_to_charptr(club_parsed.contact.email) catch return FetchStatus.OutOfMemory,
                .phone = slice_deepcopy_to_charptr(club_parsed.contact.phone) catch return FetchStatus.OutOfMemory,
                .address = .{
                    .city = slice_deepcopy_to_charptr(club_parsed.contact.city) catch return FetchStatus.OutOfMemory,
                    .zip = zipval, 
                    .street = slice_deepcopy_to_charptr(club_parsed.contact.street) catch return FetchStatus.OutOfMemory,
                }
            },
            .gyms = gyms.ptr,
            .gym_n = @intCast(club_parsed.gyms.len)
        };
    }

    association.* = .{
        .name_short = ASSOCIATION_CODES[@intFromEnum(association_code)],
        .name_long = "UNKNOWN",
        .leagues = leagues.ptr,
        .league_n = @intCast(leagues.len),
        .clubs = clubs.ptr,
        .club_n = @intCast(clubs.len)
    };

    return FetchStatus.Ok;
}

//base_infos_present: Whether to fetch the base infos that fetch_associations fetches already
//This function will not create an Association. The value in league will remain null
export fn cycleu_fetch_league(
    league: *League,
    association_code: AssociationType,
    league_name_unescaped: char_ptr,
    base_infos_present: bool,
    recursive: bool
) callconv(.C) FetchStatus {
    if (curl == null) return FetchStatus.CURL;

    const league_name = c.curl_easy_escape(curl, league_name_unescaped, @intCast(std.mem.span(league_name_unescaped).len));
    defer c.curl_free(league_name);

    const league_slice = league_name[0..std.mem.len(league_name)];
    const url_general = std.fmt.allocPrint(allocator, "{s}{s}.{s}/leagues/{s} ", .{
        URL_PROTOCOLS[@intFromEnum(URLProtocol.HTTPS)],
        ASSOCIATION_CODES[@intFromEnum(association_code)],
        URL_BASE, league_slice
    }) catch return FetchStatus.OutOfMemory;
    url_general[url_general.len - 1] = 0;
    defer allocator.free(url_general);

    //We need to convert it to a c-string later, therefor add a \0 at the end
    const url_ranking = std.fmt.allocPrint(allocator, "{s}{s}", .{url_general[0..url_general.len - 1], "/ranking "}) catch return FetchStatus.OutOfMemory;
    url_ranking[url_ranking.len - 1] = 0;
    defer allocator.free(url_ranking);
    
    //We need to convert it to a c-string later, therefor add a \0 at the end
    const url_teams = std.fmt.allocPrint(allocator, "{s}{s}", .{url_general[0..url_general.len - 1], "/teams "}) catch return FetchStatus.OutOfMemory;
    url_teams[url_teams.len - 1] = 0;
    defer allocator.free(url_teams);

    if (!base_infos_present) {
        var json_general: []u8 = undefined;
        const ret_val = fetch_url(@ptrCast(url_general), &json_general);
        if (ret_val != FetchStatus.Ok) {
            print("failed to fetch league general infos :(", .{});
            return ret_val;
        }
        defer allocator.free(json_general);

        print("SUCCESS: LEAGUE: Received json_general:\n{s}", .{json_general});

        const _General = struct {
            shortName: []const u8,
            longName: []const u8,
            hasNonCompetitive: bool,
            season: []const u8,
            manager: struct {
                name: []const u8,
                email: []const u8,
                street: []const u8,
                zip: []const u8,
                city: []const u8,
                phone: []const u8
            },
            rules: [][]const u8,
            lastImport: []const u8
        };

        const league_parsed_long = std.json.parseFromSlice(_General, allocator, json_general, .{.ignore_unknown_fields = true}) catch |err| {
            print("JSON for Leagues general info are wrong format: {s}\n", .{@errorName(err)});
            return FetchStatus.JSONMisformated;
        };
        defer league_parsed_long.deinit();

        const league_parsed = league_parsed_long.value;

        const zipval: u32 = std.fmt.parseInt(u32, league_parsed.manager.zip, 10) catch 0;
        league.* = .{
            .name_short = slice_deepcopy_to_charptr(league_parsed.shortName) catch return FetchStatus.OutOfMemory,
            .name_long = slice_deepcopy_to_charptr(league_parsed.longName) catch return FetchStatus.OutOfMemory,
            .competitive = !league_parsed.hasNonCompetitive,
            .season = std.fmt.parseInt(u16, league_parsed.season, 10) catch return FetchStatus.JSONMisformated,
            .manager = .{
                .name = slice_deepcopy_to_charptr(league_parsed.manager.name) catch return FetchStatus.OutOfMemory,
                .email = slice_deepcopy_to_charptr(league_parsed.manager.email) catch return FetchStatus.OutOfMemory,
                .phone = slice_deepcopy_to_charptr(league_parsed.manager.phone) catch return FetchStatus.OutOfMemory,
                .address = .{
                    .city = slice_deepcopy_to_charptr(league_parsed.manager.city) catch return FetchStatus.OutOfMemory,
                    .zip = zipval,
                    .street = slice_deepcopy_to_charptr(league_parsed.manager.street) catch return FetchStatus.OutOfMemory 
                },
            },
            .matchdays = undefined,
            .matchday_n = 0,
            .teams = undefined,
            .team_n = 0,
            .ranks = undefined,
            .rank_n = 0,
            .rules = slice_array_deepcopy_to_charptr(league_parsed.rules) catch return FetchStatus.OutOfMemory,
            .rule_n = @intCast(league_parsed.rules.len),
            .last_update = 0
                // TODO .last_update = league_parsed.lastImport
        };
    }

    if(recursive) {
        //First we need to download /matchday because we dont know how many matchdays there are
        const url_matchdays = std.fmt.allocPrint(allocator, "{s}{s}", .{url_general[0..url_general.len - 1], "/matchdays "}) catch return FetchStatus.OutOfMemory;
        url_matchdays[url_matchdays.len - 1] = 0;
        defer allocator.free(url_matchdays);

        var json_matchdays: []u8 = undefined;
        var ret_val = fetch_url(@ptrCast(url_matchdays), &json_matchdays);
        if (ret_val != FetchStatus.Ok) {
            print("failed to fetch the amount of matchdays in League\n", .{});
            return ret_val;
        }
        defer allocator.free(json_matchdays);
        
        const matchdays_parsed = std.json.parseFromSlice(std.json.Value, allocator, json_matchdays, .{}) catch |err| {
            print("Corrupt Matchdays metadata JSON File: {s}\n", .{@errorName(err)});
            return FetchStatus.JSONMisformated;
        };
        defer matchdays_parsed.deinit();

        var matchdays_count: ?u8 = null;
        if(matchdays_parsed.value != .array){
            print("Matchdays metadata JSON File is not an array! Wrong Format!\n", .{});
            return FetchStatus.JSONMisformated;
        }
        matchdays_count = @intCast(matchdays_parsed.value.array.items.len);
        
        const matchdays = allocator.alloc(Matchday, @intCast(matchdays_count.?)) catch return FetchStatus.OutOfMemory;
        for(0..@intCast(matchdays_count.?)) |i| {
            ret_val = cycleu_fetch_matchday(&(matchdays[0..matchdays_count.?][i]), association_code, league.name_short, @intCast(i+1));
            if(ret_val != FetchStatus.Ok)
                return ret_val;
        }
        league.matchdays = matchdays.ptr;
        league.matchday_n = @intCast(matchdays.len);
    }

    var json_teams: []u8 = undefined;
    var ret_val = fetch_url(@ptrCast(url_teams), &json_teams);
    if (ret_val != FetchStatus.Ok) {
        print("failed to fetch league teams:(", .{});
        return ret_val;
    }
    defer allocator.free(json_teams);

    const _Team = struct {
        id: []const u8,
        name: []const u8,
        clubName: []const u8,
        leagueShortName: []const u8,
        leagueLongName: []const u8,
        nonCompetitive: bool,
        lastImport: []const u8,
        players: []struct {
            name: []const u8,
            uciCode: []const u8
        }
    };

    const teams_parsed = std.json.parseFromSlice([]_Team, allocator, json_teams, .{.ignore_unknown_fields = true}) catch |err| {
        print("JSON for Leagues ranking are wrong format: {s}\n", .{@errorName(err)});
        return FetchStatus.JSONMisformated;
    };
    defer teams_parsed.deinit();

    var teams = allocator.alloc(Team, teams_parsed.value.len) catch return FetchStatus.OutOfMemory;
    for (teams_parsed.value, 0..) |team, i| {
        var players = allocator.alloc(Player, team.players.len) catch return FetchStatus.OutOfMemory;
        for (team.players, 0..) |player, j| {
            players[j] = .{
                .name = slice_deepcopy_to_charptr(player.name) catch return FetchStatus.OutOfMemory,
                .uci_code = slice_deepcopy_to_charptr(player.uciCode) catch return FetchStatus.OutOfMemory,
            };
        }

        teams[i] = .{
            .club_name = slice_deepcopy_to_charptr(team.clubName) catch return FetchStatus.OutOfMemory,
            .name = slice_deepcopy_to_charptr(team.name) catch return FetchStatus.OutOfMemory,
            .players = players.ptr,
            .player_n = @intCast(players.len),
        };
    }
    
    league.teams = teams.ptr;
    league.team_n = @intCast(teams.len);


    var json_ranking: []u8 = undefined;
    ret_val = fetch_url(url_ranking, &json_ranking);
    if (ret_val != FetchStatus.Ok) {
        print("failed to fetch league ranking:(", .{});
        return ret_val;
    }
    defer allocator.free(json_ranking);

    const _Ranking = struct {
        team: []const u8,
        games: usize,
        goalsPlus: usize,
        goalsMinus: usize,
        goalsDiff: isize,
        points: usize,
        rank: usize
    };
    
    const ranking_parsed = std.json.parseFromSlice([]_Ranking, allocator, json_ranking, .{.ignore_unknown_fields = true}) catch |err| {
        print("JSON for Leagues ranking are wrong format: {s}\n", .{@errorName(err)});
        return FetchStatus.JSONMisformated;
    };
    defer ranking_parsed.deinit();

    var ranks = allocator.alloc(Rank, ranking_parsed.value.len) catch return FetchStatus.OutOfMemory;
    for (0.., ranking_parsed.value) |i, rank_parsed| {
        var team_index: ?u8 = null;
        for (league.teams[0..league.team_n], 0..) |team, j| {
            if (std.mem.eql(u8, std.mem.span(team.name), rank_parsed.team)) {
                team_index = @intCast(j);
                break;
            }
        }
        if (team_index == null) {
            print("ERROR: We are unable to match Teamname: '{s}' to the league teams\n", .{rank_parsed.team});
            return FetchStatus.JSONMisformated;
        }
        ranks[i] = .{
            .team = &league.teams[@intCast(team_index.?)],
            .games_amount = @intCast(rank_parsed.games),
            .goals_plus = @intCast(rank_parsed.goalsPlus),
            .goals_minus = @intCast(rank_parsed.goalsMinus),
            .points = @intCast(rank_parsed.points),
            .rank = @intCast(rank_parsed.rank)
        };
    }
    league.rank_n = @intCast(ranking_parsed.value.len);
    league.ranks = ranks.ptr;

    return FetchStatus.Ok;
}

export fn cycleu_fetch_matchday(
    matchday: *Matchday,
    association_code: AssociationType,
    league_name_unescaped: char_ptr,
    number: u8,
) callconv(.C) FetchStatus {
    if (curl == null) return FetchStatus.CURL;

    const league_name = c.curl_easy_escape(curl, league_name_unescaped, @intCast(std.mem.span(league_name_unescaped).len));
    defer c.curl_free(league_name);

    const url_matchday = std.fmt.allocPrint(allocator, "{s}{s}.{s}/leagues/{s}/matchdays/{d} ", .{
        URL_PROTOCOLS[@intFromEnum(URLProtocol.HTTPS)],
        ASSOCIATION_CODES[@intFromEnum(association_code)],
        URL_BASE, league_name, number
    }) catch return FetchStatus.OutOfMemory;
    url_matchday[url_matchday.len-1] = 0;
    defer allocator.free(url_matchday);

    var json_matchday: []u8 = undefined;
    const ret_val = fetch_url(@ptrCast(url_matchday), &json_matchday);
    if (ret_val != FetchStatus.Ok) {
        print("failed to fetch matchday:(", .{});
        return ret_val;
    }
    defer allocator.free(json_matchday);
    print("JSON MATCHDAY {d}.) {s}", .{number, json_matchday});

    const _Matchday = struct {
        leagueShortName: []const u8,
        leagueLongName: []const u8,
        number: usize,
        start: []const u8,
        gym: struct {
            name: []const u8,
            street: []const u8,
            zip: []const u8,
            city: []const u8,
            phone: []const u8
        },
        hostClub: []const u8,
        lastImport: []const u8,
        teams: []struct {
            name: []const u8,
            present: bool,
            players: []struct {
                name: []const u8,
                uciCode: []const u8,
                regular: bool
            }
        },
        games: []struct {
            number: usize,
            teamA: []const u8,
            teamB: []const u8,
            goalsA: isize = -1,
            goalsB: isize = -1,
            //cycleball.eu uses these fields in 3 possible ways:
            //1. state open + no entry (yet) => "goalsAHalf" = null
            //2. state open + entry => "goalsAHalf" = 3
            //3. state closed => no goalsAHalf entry
            //We transform that into -1 for nothing or null and a >= 0 otherwise in Game
            //goalsAHalf: ?isize = -1,
            //goalsBHalf: ?isize = -1,
            state: []const u8
        },
        incidents: ?[]std.json.Value //TODO find out how incidents work
    };

    const matchday_parsed_long = std.json.parseFromSlice(_Matchday, allocator, json_matchday, .{.ignore_unknown_fields = true}) catch |err| {
        print("JSON for Matchday has wrong format: {s}\n", .{@errorName(err)});
        return FetchStatus.JSONMisformated;
    };
    defer matchday_parsed_long.deinit();

    //to extract goalsAHalf we need to parse it manually...
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, json_matchday, .{}) catch return FetchStatus.JSONMisformated;
    defer parsed.deinit();

    const games_array = parsed.value.object.get("games").?.array;
    var goalsAHalf: []i8 = allocator.alloc(i8, games_array.items.len) catch return FetchStatus.OutOfMemory;
    var goalsBHalf: []i8 = allocator.alloc(i8, games_array.items.len) catch return FetchStatus.OutOfMemory;
    defer allocator.free(goalsAHalf);
    defer allocator.free(goalsBHalf);
    for(games_array.items, 0..) |game, i| {
        const goalsAHalf_value = game.object.get("goalsAHalf");
        const goalsBHalf_value = game.object.get("goalsBHalf");

        goalsAHalf[i] = if(goalsAHalf_value != null and goalsAHalf_value.? != .null) @intCast(goalsAHalf_value.?.integer) else -1;
        goalsBHalf[i] = if(goalsBHalf_value != null and goalsAHalf_value.? != .null) @intCast(goalsBHalf_value.?.integer) else -1;
    }

    const matchday_parsed = matchday_parsed_long.value;

    const teams = allocator.alloc(Matchday_Team, matchday_parsed.teams.len) catch return FetchStatus.OutOfMemory;
    for (0.., matchday_parsed.teams) |i, team| {
        const players = allocator.alloc(Matchday_Player, team.players.len) catch return FetchStatus.OutOfMemory;
        for (0.., team.players) |j, player| {
            players[j] = .{
                .player = .{
                    .name = slice_deepcopy_to_charptr(player.name) catch return FetchStatus.OutOfMemory,
                    .uci_code = slice_deepcopy_to_charptr(player.uciCode) catch return FetchStatus.OutOfMemory
                },
                .regular = player.regular
            };
        }

        teams[i] = .{
            .name = slice_deepcopy_to_charptr(team.name) catch return FetchStatus.OutOfMemory,
            .present = team.present,
            .players = players.ptr,
            .player_n = @intCast(players.len)
        };
    }

    const games = allocator.alloc(Game, matchday_parsed.games.len) catch return FetchStatus.OutOfMemory;
    for (0.., matchday_parsed.games) |i, game| {
        var teama_index: ?u8 = null;
        var teamb_index: ?u8 = null;
        for (teams, 0..) |team, j| {
            if (std.mem.eql(u8, std.mem.span(team.name), game.teamA))
                teama_index = @intCast(j)
            else if (std.mem.eql(u8, std.mem.span(team.name), game.teamB))
                teamb_index = @intCast(j);
            //print("Teamname(A|B): '{s}'|'{s}', ist es '{s}'? ({d}|{d})\n", .{game.teamA, game.teamB, std.mem.span(team.name), teama_index orelse 200, teamb_index orelse 200});
            if ((teama_index != null) and (teamb_index != null))
                break;
        }
        if (teama_index == null) {
            print("ERROR: Could not find Team A from Game {d}: '{s}' from Teams in Matchday\n", .{game.number, game.teamA});
            return FetchStatus.JSONMisformated;
        }
        if (teamb_index == null) {
            print("ERROR: Could not find Team B from Game {d}: '{s}' from Teams in Matchday\n", .{game.number, game.teamB});
            return FetchStatus.JSONMisformated;
        }

        //TODO make this more robust. Catch other option and return failure if both are false
        const is_writable = std.mem.eql(u8, game.state, "Open");

        games[i] = .{
            .number = @intCast(game.number),
            .team_a = &(teams[@intCast(teama_index.?)]),
            .team_b = &(teams[@intCast(teamb_index.?)]),
            .goals = .{
                .a = @intCast(game.goalsA),
                .b = @intCast(game.goalsB),
                .half = .{
                    .a = goalsAHalf[i],
                    .b = goalsBHalf[i]
                }
            },
            .is_writable = is_writable
        };
    }

    //const zipval: u32 = std.fmt.parseInt(u32, matchday_parsed.gym.zip, 10) catch 0;
    matchday.* = .{
        .number = @intCast(matchday_parsed.number),
        .start = 0, //TODO implement string -> time_t
        .gym = .{
            .name = slice_deepcopy_to_charptr(matchday_parsed.gym.name) catch return FetchStatus.OutOfMemory,
            .phone = slice_deepcopy_to_charptr(matchday_parsed.gym.phone) catch return FetchStatus.OutOfMemory,
            .address = .{
                .city = slice_deepcopy_to_charptr(matchday_parsed.gym.city) catch return FetchStatus.OutOfMemory,
                .street = slice_deepcopy_to_charptr(matchday_parsed.gym.street) catch return FetchStatus.OutOfMemory,
                .zip = std.fmt.parseInt(u32, matchday_parsed.gym.zip, 10) catch 0
            }
        },
        .host_club_name = slice_deepcopy_to_charptr(matchday_parsed.hostClub) catch return FetchStatus.OutOfMemory, 
        .teams = teams.ptr,
        .team_n = @intCast(matchday_parsed.teams.len),
        .games = games.ptr,
        .game_n = @intCast(matchday_parsed.games.len)
    };

    return FetchStatus.Ok;
}

export fn cycleu_fetch_club(
    club: *Club,
    association_code: AssociationType,
    club_name: char_ptr,
) callconv(.C) FetchStatus {
    if (curl == null) return FetchStatus.CURL;

    const url =
        URL_PROTOCOLS[@intFromEnum(URLProtocol.HTTPS)] ++ 
        ASSOCIATION_CODES[@intFromEnum(association_code)] ++ 
        "." ++ URL_BASE ++ "/clubs";

    var json_clubs: []u8 = undefined;
    const ret_val = fetch_url(url, &json_clubs);
    if (ret_val != FetchStatus.Ok) {
        print("failed to fetch association clubs {s} :(", .{@tagName(ret_val)});
        return ret_val;
    }
    defer allocator.free(json_clubs);

    print("SUCCESS: Received Association clubs:\n", .{});

    const _Club = struct {
        name: []const u8,
        city: []const u8,
        contact: struct {
            name: []const u8,
            email: []const u8,
            street: []const u8,
            zip: []const u8,
            city: []const u8,
            phone: []const u8
        },
        gyms: []struct {
            name: []const u8,
            street: []const u8,
            zip: []const u8,
            city: []const u8,
            phone: []const u8
        }
    };

    const clubs_parsed = std.json.parseFromSlice([]_Club, allocator, json_clubs, .{.ignore_unknown_fields = true}) catch |err| {
        print("JSON for Clubs is wrong format: {s}\n", .{@errorName(err)});
        return FetchStatus.JSONMisformated;
    };
    defer clubs_parsed.deinit();


    var club_index: ?usize = null;
    for (clubs_parsed.value, 0..) |club_parsed, i| {
        if(std.mem.eql(u8, club_parsed.name, std.mem.span(club_name))){
            club_index = i;
            break;
        }
    }
    if(club_index == null) {
        print("ERROR: Could not find club named: '{s}' in Association '{s}'\n", .{club_name, @tagName(association_code)});
        return FetchStatus.JSONMisformated;
    }

    const club_parsed = clubs_parsed.value[club_index.?];

    const gyms = allocator.alloc(Gym, club_parsed.gyms.len) catch return FetchStatus.OutOfMemory;
    for (club_parsed.gyms, 0..) |gym, j| {
        gyms[j] = .{
            .name = slice_deepcopy_to_charptr(gym.name) catch return FetchStatus.OutOfMemory,
            .phone = slice_deepcopy_to_charptr(gym.phone) catch return FetchStatus.OutOfMemory,
            .address = .{
                .city = slice_deepcopy_to_charptr(gym.city) catch return FetchStatus.OutOfMemory,
                .zip = std.fmt.parseInt(u32, gym.zip, 10) catch 0,
                .street = slice_deepcopy_to_charptr(gym.street) catch return FetchStatus.OutOfMemory
            }
        };
    }

    club.* = .{
        .name = slice_deepcopy_to_charptr(club_parsed.name) catch return FetchStatus.OutOfMemory,
        .city = slice_deepcopy_to_charptr(club_parsed.city) catch return FetchStatus.OutOfMemory,
        .contact = .{
            .name = slice_deepcopy_to_charptr(club_parsed.contact.name) catch return FetchStatus.OutOfMemory,
            .email = slice_deepcopy_to_charptr(club_parsed.contact.email) catch return FetchStatus.OutOfMemory,
            .phone = slice_deepcopy_to_charptr(club_parsed.contact.phone) catch return FetchStatus.OutOfMemory,
            .address = .{
                .city = slice_deepcopy_to_charptr(club_parsed.contact.city) catch return FetchStatus.OutOfMemory,
                .zip = std.fmt.parseInt(u32, club_parsed.contact.zip, 10) catch 0, 
                .street = slice_deepcopy_to_charptr(club_parsed.contact.street) catch return FetchStatus.OutOfMemory,
            }
        },
        .gyms = gyms.ptr,
        .gym_n = @intCast(club_parsed.gyms.len)
    };

    return FetchStatus.Ok;
}


export fn cycleu_write_result(
    game: Game,
    game_number: u8,
    league_name_short: char_ptr,
    association_name_short: char_ptr
) callconv(.C) FetchStatus {
    if (curl == null) return FetchStatus.CURL;

    //TODO make json from input
    const json: char_ptr = "{goalsA: 0}";
    const url: char_ptr = "https://test.de";

    _ = c.curl_easy_setopt(curl, c.CURLOPT_URL, url);
    _ = c.curl_easy_setopt(curl, c.CURLOPT_CUSTOMREQUEST, "PUT");
    _ = c.curl_easy_setopt(curl, c.CURLOPT_POSTFIELDS, json);
    //TODO does this work?
    var headers: ?*c.struct_curl_slist = null;
    headers = c.curl_slist_append(headers, "Content-Type: application/json");
    _ = c.curl_easy_setopt(curl, c.CURLOPT_HTTPHEADER, headers);

    const ret_code = c.curl_easy_perform(curl);
    if (ret_code != c.CURLE_OK) {
        //Handle different types of errors and ret correct FetchStatus
        print("ERROR: Failed writing game results!: {s}\n", .{c.curl_easy_strerror(ret_code)});
        return FetchStatus.Unknown;
    }

    if (headers) |h| {
        c.curl_slist_free_all(h);
    }

    // TODO
    _ = game;
    _ = game_number;
    _ = league_name_short;
    _ = association_name_short;
    return FetchStatus.Ok;
}

export fn cycleu_deinit() callconv(.C) void {
    c.curl_easy_cleanup(curl);
    c.curl_global_cleanup();
}

fn receive_json(src: void_ptr, size: usize, nmemb: usize, dest: *[]u8) callconv(.C) usize {
    if (size != @sizeOf(u8)) {
        print("ERROR: We did not receive json data from curl aka cycleball.eu\n", .{});
        return 0;
    }
    
    const new_data = allocator.alloc(u8, dest.len + nmemb) catch return 0;
    std.mem.copyForwards(u8, new_data[0..dest.len], dest.*);
    std.mem.copyForwards(u8, new_data[dest.len..], @as([*]const u8, @ptrCast(src))[0..nmemb]);
    if (dest.len > 0) allocator.free(dest.*);
    dest.ptr = new_data.ptr;
    dest.len = new_data.len;
    
    //print("SUCCESS: Received Association League (RECEIVE_JSON):\n{s}\n", .{dest.*});

    return size * nmemb;
}

fn slice_deepcopy_to_charptr(input: []const u8) ![*:0]const u8 {
    var buffer = try allocator.alloc(u8, input.len + 1);
    std.mem.copyForwards(u8, buffer[0..input.len], input);
    buffer[input.len] = 0;
    return @as([*:0]const u8, @ptrCast(buffer.ptr));
}

fn slice_array_deepcopy_to_charptr(input: []const []const u8) ![*][*:0]const u8 {
    var buffer = try allocator.alloc([*:0]const u8, input.len);
    for (input, 0..) |str, i|
        buffer[i] = try slice_deepcopy_to_charptr(str);
    return buffer.ptr;
}

fn fetch_url(url: []const u8, dest: *[]u8) FetchStatus {
    var callback_data: []u8 = &[_]u8{};
    _ = c.curl_easy_setopt(curl, c.CURLOPT_URL, url.ptr);
    _ = c.curl_easy_setopt(curl, c.CURLOPT_WRITEDATA, &callback_data);

    print("DEBUG: fetching url {s}\n", .{url});

    const ret_code = c.curl_easy_perform(curl);
    if (ret_code != c.CURLE_OK) {
        //Handle different types of errors and ret correct FetchStatus
        print("ERROR: Failed fetching JSON!\nURL: {s}\nError: {s}\n", .{url, c.curl_easy_strerror(ret_code)});
        return FetchStatus.Unknown;
    }

    dest.* = callback_data;
    //print("SUCCESS: Received Association League (FETCH_URL 2):\n{s}\n", .{dest.*});
    return FetchStatus.Ok;
}

test "main" {
    _ = cycleu_init();
    defer cycleu_deinit();

    //var ass_decoy: Association = undefined;
    //var ret_val = cycleu_fetch_association(&ass_decoy, AssociationType.Deutschland, false);
    //if (ret_val != FetchStatus.Ok) {
    //    if (ret_val == FetchStatus.JSONMisformated)
    //        print("Json was misformated. Fuck you\n", .{});
    //    return;
    //}
    //defer ass_decoy.deinit();
    
    //print("league {d}: {s} ({s})\n", .{1, ass_decoy.leagues[1].name_long, ass_decoy.leagues[1].name_short});

    var league: League = undefined;
    const ret_val = cycleu_fetch_league(&league, AssociationType.Deutschland, "b23", false, true);
    if (ret_val != FetchStatus.Ok) {
        if (ret_val == FetchStatus.JSONMisformated)
            print("Json was misformated. Fuck you\n", .{});
        return;
    }
    print("We got {d} Matchdays\n", .{league.matchday_n});
    defer league.deinit();

    //var matchday_decoy: Matchday = undefined;
    //ret_val = cycleu_fetch_matchday(&matchday_decoy, AssociationType.Deutschland, "b11", 1);
    //if (ret_val != FetchStatus.Ok) {
    //    if (ret_val == FetchStatus.JSONMisformated)
    //        print("Json was misformated. Fuck you\n", .{});
    //    return;
    //}
    //defer matchday_decoy.deinit();

    //var team_index: ?u32 = null;
    //for(league_decoy.teams[0..league_decoy.team_n], 0..) |team, i| {
    //    if(std.mem.eql(u8, std.mem.span(team.name), std.mem.span(matchday_decoy.games[0].team_a.name))) {
    //        team_index = @intCast(i);
    //        break;
    //    }
    //}
    //if(team_index == null){
    //    print("ERROR: Could not find Team {s} in League {s}:(\n", .{matchday_decoy.games[0].team_a.name, league_decoy.name_long});
    //    return;
    //}

    //var club: Club = undefined;
    //ret_val = cycleu_fetch_club(&club, AssociationType.Deutschland, league_decoy.teams[@intCast(team_index.?)].club_name);
    //if (ret_val != FetchStatus.Ok) {
    //    if (ret_val == FetchStatus.JSONMisformated)
    //        print("Json was misformated. Fuck you\n", .{});
    //    return;
    //}
    //defer club.deinit();

    //print("GGGame 1: {s}({s}, {s})\n", .{matchday_decoy.games[0].team_a.name, club.name, club.contact.name});

    for (league.ranks[0..league.rank_n], 0..) |rank, i| {
        print("{d:2}: {s:30}, {d}, {d:>3}:{d:<3}, {d}\n", .{i, rank.team.name, rank.games_amount, rank.goals_plus, rank.goals_minus, rank.points});
    }
    
    for(league.matchdays[0..league.matchday_n]) |matchday| {
        for (matchday.games[0..matchday.game_n], 0..) |game, i| {
            print("{d:2}.) {s:>20} {d:>2}:{d:<2}({d:>2}:{d:<2}) {s:<20}\n", .{i, game.team_a.name, game.goals.a, game.goals.b, game.goals.half.a, game.goals.half.b, game.team_b.name});
        }
    }

    //for (ass_decoy.leagues[1].teams[0..ass_decoy.leagues[1].team_n], 0..) |team, i| {
    //    print("Team {d}: {s}\n", .{i, team.name});
    //}
}
