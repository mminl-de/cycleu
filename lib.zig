//! libcycleu – TODO description

// TODO COMMENT ALL
// TODO FINAL generate docs
const std = @import("std");
const c = @cImport(@cInclude("curl/curl.h"));

const char_ptr = [*:0]const u8;
const void_ptr = ?*anyopaque;
const time_t = i64;
const print = std.debug.print;

const allocator: std.mem.Allocator = std.heap.c_allocator;

//TODO can we make this pub or do we really have to write a function for this
var CYCLEU_USE_CACHE: bool = false;

var curl: ?*c.CURL = null;

const UrlPrefix = enum(u8) {HTTPS, HTTP, FILE};
const UrlPrefixCode = [_][]const u8 {"https://", "http://", "file://"}; // TODO CONSIDER file://
const UrlBase = "cycleball.eu/api";

//TODO Reverse engineer API for getting all available Associations
const Associations = enum(u8) {Deutschland, Bayern, Brandenburg, BadenWuerttemberg, Hessen, RheinlandPfalz};
const AssociationsCode = [_]*const [2:0]u8{"de", "by", "bb", "bw", "he", "rp"};

const FetchStatus = enum(u8) {Ok, AuthCodeWrong, LeagueUnknown, GameUnknown, Internet, Curl, Unknown, OutOfMemory};

const Association = extern struct {
    name_short: char_ptr,
    name_long: char_ptr,
    leagues: *const League,
    league_n: u8,
    clubs: *const Club,
    club_n: u8
};

const League = extern struct {
    association: *const Association,
    name_short: char_ptr,
    name_long: char_ptr,
    competitive: bool,
    season: u16,
    manager: extern struct {
        name: char_ptr,
        email: char_ptr,
        address: extern struct {
            city: char_ptr,
            zip: u32,
            street: char_ptr
        },
        phone: char_ptr
    },
    ranking: Ranking,
    rules: *const char_ptr,
    rule_n: u8,
    last_update: time_t,
};

const Matchday = extern struct {
    league: *const League,
    number: u8,
    start: time_t,
    gym: *const Gym,
    host_club: *const Club,
    teams: *const extern struct {
        orig_team: *const Team,
        present: bool,
        players: *const extern struct {
            player: *const Player,
            regular: bool
        },
        player_n: u8
    },
    team_n: u8,
    games: *const Game,
    game_n: u8
    //TODO how do incidents work? We need an example
};

const Game = extern struct {
    matchday: *const Matchday,
    number: u8,
    team_a: *const Team,
    team_b: *const Team,
    goals: extern struct {
        a: u8,
        b: u8,
        half: extern struct {
            a: u8,
            b: u8
        }
    },
    is_writable: bool
};

const Team = extern struct {
    club: *const Club,
    name: char_ptr,
    players: *const Player,
    player_n: u8,
    non_regular_players: *const extern struct {
        player: *const Player,
        matchdays: *const *const Matchday,
        matchday_n: u8
    },
    non_regular_player_n: u8
};

const Player = extern struct {
    name: char_ptr,
    uci_code: char_ptr,
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
    gyms: *const Gym,
    gym_n: u8
};

const Gym = extern struct {
    club: *const Club,
    name: char_ptr,
    phone: char_ptr,
    address: extern struct {
        city: char_ptr,
        zip: u32,
        street: char_ptr
    }
};

const Ranking = extern struct {
    league: *const League,
    ranks: *const extern struct {
        team: *const Team,
        games_amount: u8,
        goals_plus: u16,
        goals_minus: u16,
        points: u16
    },
    rank_n: u8
};

const Callback_data = extern struct {
    data: [*]u8,
    len: usize
};

fn cycleu_init() bool {
    _ = c.curl_global_init(c.CURL_GLOBAL_DEFAULT);
    curl = c.curl_easy_init() orelse {
        print("ERROR: cURL is striking. Come back tomorrow!\n", .{});
        return false;
    };

    _ = c.curl_easy_setopt(curl, c.CURLOPT_FOLLOWLOCATION, @as(u8, 1));
    _ = c.curl_easy_setopt(curl, c.CURLOPT_USERAGENT, "curl/8.13.0");
    _ = c.curl_easy_setopt(curl, c.CURLOPT_WRITEFUNCTION, receive_json);

    return true;
}

fn receive_json(src: void_ptr, size: usize, nmemb: usize, dest: *void_ptr) callconv(.C) usize {
    if (size != @sizeOf(u8)) {
        print("ERROR: We did not receive json data from curl aka cycleball.eu\n", .{});
        return 0;
    }
    const out = @as(*Callback_data, @ptrCast(dest));

    const mem = allocator.alloc(u8, size*nmemb) catch return 0;
    std.mem.copyForwards(u8, mem, @as([*]const u8, @ptrCast(src))[0..size*nmemb]);

    out.*.data = mem.ptr;
    out.*.len = nmemb;

    return size * nmemb;
}

// TODO ASK what does this function do and return?
fn fetch_url(url: char_ptr, dest: *[]u8) FetchStatus {

    var callback_data: Callback_data = undefined;
    _ = c.curl_easy_setopt(curl, c.CURLOPT_URL, url);
    _ = c.curl_easy_setopt(curl, c.CURLOPT_WRITEDATA, &callback_data);

    print("DEBUG: fetching url {s}\n", .{url});

    const ret_code = c.curl_easy_perform(curl);
    if (ret_code != c.CURLE_OK) {
        //Handle different types of errors and ret correct FetchStatus
        print("ERROR: Failed fetching JSON!\nURL: {s}\nError: {s}\n", .{url, c.curl_easy_strerror(ret_code)});
        return FetchStatus.Unknown;
    }

    dest.* = callback_data.data[0..callback_data.len];
    return FetchStatus.Ok;
}

export fn cycleu_deinit() void {
    c.curl_easy_cleanup(curl);
    c.curl_global_cleanup();
}


export fn cycleu_fetch_association(
    association: *Association,
    association_code: Associations,
    recursive: bool,
) FetchStatus {
    if (curl == null) return FetchStatus.Curl;
    const url =
        UrlPrefixCode[@intFromEnum(UrlPrefix.HTTPS)] ++ 
        AssociationsCode[@intFromEnum(association_code)] ++ 
        "." ++ UrlBase ++ "/leagues";

    var json_str: []u8 = undefined;
    const ret_val = fetch_url(url, &json_str);
    if(ret_val != FetchStatus.Ok){
        print("failed to fetch association {s}:(", .{@tagName(ret_val)});
        return ret_val;
    }
    defer allocator.free(json_str);

    //TODO parse json into leagues

    association.name_short = AssociationsCode[@intFromEnum(association_code)];
    association.name_long = "UNKNOWN"; //TODO

    print("SUCCESS: Received Association:\n{s}", .{json_str});

    _ = recursive;
    return undefined;
}

export fn cycleu_fetch_league(
    league: *League,
    association_code: Associations,
    league_name: char_ptr,
    recursive: bool
) FetchStatus {
    if (curl == null) return FetchStatus.Curl;
    //TODO league name could contain whitespaces!
    const league_slice = league_name[0..std.mem.len(league_name)];
    const url_general = std.fmt.allocPrint(allocator, "{s}{s}.{s}/leagues/{s}", .{
        UrlPrefixCode[@intFromEnum(UrlPrefix.HTTPS)],
        AssociationsCode[@intFromEnum(association_code)],
        UrlBase, league_slice
    }) catch return FetchStatus.OutOfMemory;
    defer allocator.free(url_general);

    const url_ranking = std.mem.concat(allocator, u8, &.{url_general, "/ranking"}) catch return FetchStatus.OutOfMemory;
    defer allocator.free(url_ranking);
    const url_teams = std.mem.concat(allocator, u8, &.{url_general, "/teams"}) catch return FetchStatus.OutOfMemory;
    defer allocator.free(url_teams);

    var json_general: []u8 = undefined;
    var ret_val = fetch_url(@ptrCast(url_general), &json_general);
    if(ret_val != FetchStatus.Ok){
        print("failed to fetch league general infos :(", .{});
        return ret_val;
    }
    defer allocator.free(json_general);

    print("SUCCESS: LEAGUE: Received json_general:\n{s}", .{json_general});

    var json_ranking: []u8 = undefined;
    ret_val = fetch_url(@ptrCast(url_ranking), &json_ranking);
    if(ret_val != FetchStatus.Ok){
        print("failed to fetch league ranking:(", .{});
        return ret_val;
    }
    defer allocator.free(json_ranking);

    print("SUCCESS: LEAGUE: Received json_ranking:\n{s}", .{json_ranking});

    var json_teams: []u8 = undefined;
    ret_val = fetch_url(@ptrCast(url_teams), &json_teams);
    if(ret_val != FetchStatus.Ok){
        print("failed to fetch league teams:(", .{});
        return ret_val;
    }
    defer allocator.free(json_teams);

    print("SUCCESS: LEAGUE: Received json_teams:\n{s}", .{json_teams});

    print("SUCCESS: Received league: general, ranking, teams:\n", .{});

    _ = league;
    _ = recursive;
    return FetchStatus.Ok;
}

export fn cycleu_fetch_matchday(
    matchday: *Matchday,
    association_code: Associations,
    league_name: char_ptr,
    number: u8
) FetchStatus {
    if (curl == null) return FetchStatus.Curl;
    const url_matchday = std.fmt.allocPrint(allocator, "{s}{s}.{s}/leagues/{s}/matchdays/{d}", .{
        UrlPrefixCode[@intFromEnum(UrlPrefix.HTTPS)],
        AssociationsCode[@intFromEnum(association_code)],
        UrlBase, league_name, number
    }) catch return FetchStatus.OutOfMemory;
    defer allocator.free(url_matchday);

    var json_matchday: []u8 = undefined;
    const ret_val = fetch_url(@ptrCast(url_matchday), &json_matchday);
    if(ret_val != FetchStatus.Ok){
        print("failed to fetch matchday:(", .{});
        return ret_val;
    }
    defer allocator.free(json_matchday);

    print("SUCCESS: Received json_matchday:\n{s}", .{json_matchday});
   
    _ = matchday;
    return FetchStatus.Ok;
}

export fn cycleu_write_result(
    game: Game,
    game_number: u8,
    league_name_short: char_ptr,
    association_name_short: char_ptr
) FetchStatus {
    if (curl == null) return FetchStatus.Curl;

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

    _ = game;
    _ = game_number;
    _ = league_name_short;
    _ = association_name_short;
    return FetchStatus.Ok;
}

pub fn main() !void {
    _ = cycleu_init();

    var ass_decoy: Association = undefined;
    var league_decoy: League = undefined;
    var matchday_decoy: Matchday = undefined;
    _ = cycleu_fetch_association(&ass_decoy, Associations.Deutschland, false);
    _ = cycleu_fetch_league(&league_decoy, Associations.Deutschland, "b11", false);
    _ = cycleu_fetch_matchday(&matchday_decoy, Associations.Deutschland, "b11", 2);

    _ = cycleu_deinit();
}
