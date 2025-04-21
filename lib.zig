//! libcycleu – TODO description

// TODO COMMENT ALL
// TODO FINAL generate docs
const std = @import("std");
const c = @cImport({
    //@cInclude("json-c/json.h");
    //@cInclude("json-c/json_object.h");
    @cInclude("curl/curl.h");
});

const char_ptr = [*:0]const u8;
const void_ptr = ?*anyopaque;
const time_t = i64;
const print = std.debug.print;

const allocator: std.mem.Allocator = std.heap.c_allocator;

//TODO can we make this pub or do we really have to write a function for this
var CYCLEU_USE_CACHE: bool = false;

var curl: ?*c.CURL = null;

const UrlPrefix = enum(u8) {HTTPS, HTTP, FILE};
const UrlPrefixCode = [_][]const u8 {"https://", "http://", "file://"}; // file://?
const UrlBase = ".cycleball.eu/api/";

//TODO Reverse engineer API for getting all available Associations
const Associations = enum(u8) {Deutschland, Bayern, Brandenburg, BadenWuerttemberg, Hessen, RheinlandPfalz};
const AssociationsCode = [_][]const u8{"de", "by", "bb", "bw", "he", "rp"};

const FetchStatus = enum(u8) {Ok, AuthCodeWrong, LeagueUnknown, GameUnknown, Internet, Curl, Unknown};

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
fn fetch_url(url: char_ptr) []u8 {

    var callback_data: Callback_data = undefined;
    _ = c.curl_easy_setopt(curl, c.CURLOPT_URL, url);
    _ = c.curl_easy_setopt(curl, c.CURLOPT_WRITEDATA, &callback_data);

    const ret_code = c.curl_easy_perform(curl);
    if (ret_code != c.CURLE_OK) {
        print("ERROR: Failed fetching JSON!: {s}\n", .{c.curl_easy_strerror(ret_code)});
        return undefined;
    }

    const json: []u8 = callback_data.data[0..callback_data.len];
    //allocator.free(callback_data.data);

    //TODO FINAL remove debug statement
    print("JSON RECEIVED: {s}", .{json});
    return json;
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
    if (curl == null) _ = if(!cycleu_init()) return FetchStatus.Curl;
    const url =
        UrlPrefixCode[@intFromEnum(UrlPrefix.HTTPS)] ++
        //url_prefix ++
        AssociationsCode[@intFromEnum(association_code)] ++
        //association_string ++
        UrlBase ++ "leagues";

    const json_str: []const u8 = fetch_url(url);
    print("SUCCESS: Received Association:\n{s}", .{json_str});

    _ = recursive;
    _ = association;
    return undefined;
}

//export fn cycleu_fetch_league(
//    league: *League,
//    association_name_short: char_ptr,
//    league_name: char_ptr,
//    recursive: bool
//) FetchStatus {
//    if (curl == null) _ = cycleu_init();
//    //TODO league name could contain whitespaces!
//    const url_general = "https://";
//    // TODO const url_general = "https://" ++ association_name_short ++ ".cycleball.eu/api/leagues/" ++ league_name;
//    const url_ranking = url_general ++ "/ranking";
//    const url_teams = url_general ++ "/teams";
//    _ = url_ranking;
//    _ = url_teams;
//    _ = recursive;
//    _ = association_name_short;
//    _ = league_name;
//    return undefined;
//}
//
//export fn cycleu_fetch_matchday(
//    matchday: *Matchday,
//    association_name_short: char_ptr,
//    league_name_short: char_ptr,
//    number: u8
//) FetchStatus {
//    if (curl == null) _ = cycleu_init();
//    const url_matchday = "https://";
//    // TODO const url_matchday = "https://" ++ association_name_short ++ ".cycleball.eu/api/leagues/" ++ league_name_short ++ "/matchdays/" ++ number;
//    _ = url_matchday;
//    _ = association_name_short;
//    _ = league_name_short;
//    _ = number;
//    return undefined;
//}
//
//export fn cycleu_write_result(
//    game: Game,
//    game_number: u8,
//    league_name_short: char_ptr,
//    association_name_short: char_ptr
//) FetchStatus {
//    if (curl == null)
//        if (!cycleu_init())
//            return false;
//    _ = game;
//    _ = game_number;
//    _ = league_name_short;
//    _ = association_name_short;
//    return true;
//}

pub fn main() !void {
    _ = cycleu_init();
    //_ = fetch_url("https://de.cycleball.eu/api/leagues");
    const ass_decoy: *Association = undefined;
    _ = cycleu_fetch_association(ass_decoy, Associations.Deutschland, false);

    _ = cycleu_deinit();
}
