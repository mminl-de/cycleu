const std = @import("std");
const c = @cImport({
    @cInclude("json-c/json.h");
    //@cInclude("json-c/json_object.h");
    @cInclude("curl/curl.h");
});

const time_t = i64;

var CYCLEU_USE_CACHE: bool = false;

const Associations = enum {Deutschland, Bayern, Brandenburg, BadenWuerttemberg, Hessen, RheinlandPfalz};
const AssociationsCode = [][]const u8 {"de", "by", "bb", "bw", "he", "rp"};

const WriteError = error{AuthCodeWrong, LeagueUnknown, GameUnknown, Internet};

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

fn _fetch_link(link: []const u8) []const u8 {
}

fn fetch_associations(association: Associations, recursive: bool) !Association{
    const url = "https://" ++ AssociationsCode[@intFromEnum(association)] ++ ".cycleball.eu/api/leagues";
    _fetch_link(url);

    _ = recursive;
}

fn fetch_league(association: Association, league_name: []const u8, recursive: bool) !League{
    const url_general = "https://" ++ association.name_short ++ ".cycleball.eu/api/leagues/" ++ league_name;
    const url_ranking = "https://" ++ association.name_short ++ ".cycleball.eu/api/leagues/" ++ league_name ++ "/ranking";
    const url_teams = "https://" ++ association.name_short ++ ".cycleball.eu/api/leagues/" ++ league_name ++ "/teams";
}

fn fetch_matchday(league: League, number: u8) !Matchday{
    const url_matchday = "https://" ++ league.association.name_short ++ ".cycleball.eu/api/leagues/" ++ league.name_short ++ "/matchdays/" ++ number;
}

fn write_game_result(game: Game, game_number: u8, league: League) WriteError!null;
