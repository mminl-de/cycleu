const std = @import("std");
const c = @cImport({
    @cInclude("json-c/json.h");
    //@cInclude("json-c/json_object.h");
    @cInclude("curl/curl.h");
});

const time_t = i64;
const print = std.debug.print;

const allocator: std.mem.Allocator = std.heap.c_allocator;

//TODO can we make this pub or do we really have to write a function for this
var CYCLEU_USE_CACHE: bool = false;

var curl: ?*c.CURL = null;


//TODO Reverse engineer API for getting all available Associations
const Associations = enum {Deutschland, Bayern, Brandenburg, BadenWuerttemberg, Hessen, RheinlandPfalz};
const AssociationsCode = [_][]const u8 {"de", "by", "bb", "bw", "he", "rp"};

const AccessError = error{AuthCodeWrong, LeagueUnknown, GameUnknown, Internet, Curl, Unknown};

const Association = struct {
    name_short: []const u8,
    name_long: []const u8,
    leagues: []League,
    clubs: []Club
};

const League = struct {
    association: *const Association,
    name_short: []const u8,
    name_long:  []const u8,
    competitive: bool,
    season: u16,
    manager: struct {
        name: []const u8,
        email: []const u8,
        address: struct {
            city: []const u8,
            zip: u32,
            street: []const u8
        },
        phone: []const u8
    },
    ranking: Ranking,
    rules: [][]const u8,
    last_update: time_t,
};

const Matchday = struct {
    league: *const League,
    number: u8,
    start: time_t,
    gym: *const Gym,
    host_club: *const Club,
    teams: []struct {
        orig_team: *const Team,
        present: bool,
        players: []struct {
            player: *const Player,
            regular: bool
        }
    },
    games: []const Game
    //TODO how do incidents work? We need an example
};

const Game = struct {
    matchday: *const Matchday,
    number: u8,
    team_a: *const Team,
    team_b: *const Team,
    goals: struct {
        a: u8,
        b: u8,
        half: struct {
            a: u8,
            b: u8
        }
    },
    is_writable: bool
};

const Team = struct {
    club: *const Club,
    name: []const u8,
    players: []const Player,
    non_regular_players: []struct {
        player: *const Player,
        matchdays: []*const Matchday
    }
};

const Player = struct {
    name: []const u8,
    uci_code: []const u8,
};

const Club = struct {
    name: []const u8,
    city: []const u8,
    contact: struct {
        name: []const u8,
        email: []const u8,
        phone: []const u8,
        address: struct {
            city: []const u8,
            zip: u32,
            street: []const u8
        }
    },
    gyms: []const Gym
};

const Gym = struct {
    club: *const Club,
    name: []const u8,
    phone: []const u8,
    address: struct {
        city: []const u8,
        zip: u32,
        street: []const u8
    }
};

const Ranking = struct {
    league: *const League,
    ranks: []struct {
        team: *const Team,
        games_amount: u8,
        goals_plus: u16,
        goals_minus: u16,
        points: u16
    }
};

fn receive_json(data: ?*anyopaque, size: usize, nmemb: usize, json: *?*anyopaque) callconv(.C) usize {
    if(nmemb != @sizeOf(u8)){
        print("ERROR: We did not receive json data from curl aka cycleball.eu\n");
        return 1;
    }
    json.* = allocator.alloc(u8, size);
    std.mem.copyForwards(u8, json.*, data);
}

fn init_curl() AccessError!void {
    c.curl_global_init(c.CURL_GLOBAL_DEFAULT);
    curl = c.curl_easy_init() orelse {
        print("ERROR: CURL is striking. Come back tomorrow\n", .{});
        return AccessError.Curl;
    };
    c.curl_easy_setopt(curl, c.CURLOPT_FOLLOWLOCATION, 1);
    c.curl_easy_setopt(curl, c.CURLOPT_WRITEFUNCTION, receive_json);
}

fn fetch_link(link: []const u8) AccessError![]const u8 {
    var json: []const u8 = undefined;
    c.curl_easy_setopt(curl, c.CURLOPT_URL, link);
    c.curl_easy_setopt(curl, c.CURLOPT_WRITEDATA, @ptrCast(&json));
    const ret_code = c.curl_easy_perform(curl);
    if (ret_code != c.CURLE_OK) {
        print("Fetching JSON failed! Error handling is for later. For now take this dump: %s\n", .{c.curl_easy_strerror(ret_code)});
        return AccessError.Unknown;
    }
    return json;
}

pub fn fetch_associations(association: Associations, recursive: bool) !Association{
    if(curl == null)
        try init_curl();
    const url = "https://" ++ AssociationsCode[@intFromEnum(association)] ++ ".cycleball.eu/api/leagues";
    const json_str: []const u8 = fetch_link(url);

    _ = json_str;
    _ = recursive;
}

pub fn fetch_league(association_name_short: []const u8, league_name: []const u8, recursive: bool) !League{
    if(curl == null)
        try init_curl();
    //TODO league name could contain whitespaces!
    const url_general = "https://" ++ association_name_short ++ ".cycleball.eu/api/leagues/" ++ league_name;
    const url_ranking = url_general ++ "/ranking";
    const url_teams = url_general ++ "/teams";
    _ = url_ranking;
    _ = url_teams;
    _ = recursive;
}

pub fn fetch_matchday(association_name_short: []const u8, league_name_short: []const u8, number: u8) !Matchday{
    if(curl == null)
        try init_curl();
    const url_matchday = "https://" ++ association_name_short ++ ".cycleball.eu/api/leagues/" ++ league_name_short ++ "/matchdays/" ++ number;
    _ = url_matchday;
}

pub fn write_game_result(game: Game, game_number: u8, league_name_short: []const u8, association_name_short: []const u8) AccessError!void{
    if(curl == null)
        try init_curl();
    _ = game;
    _ = game_number;
    _ = league_name_short;
    _ = association_name_short;
}
