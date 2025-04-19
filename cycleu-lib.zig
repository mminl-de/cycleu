const std = @import("std");

var CYCLEU_USE_CACHE: bool = false;

const write_err = error{AUTH_CODE_WRONG, LEAGUE_UNKNOWN, GAME_UNKNOWN, INTERNET};

const Association = struct {
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
    rules: std.ArrayList([]const u8),
    last_update: i64, // i64 == time_t
    pub fn deinit(self: *Association) void {
        self.rules.deinit();
    }
};

const League = struct {

}

const Matchday = struct {

}

const Game = struct {

}

const Team = struct {

}

fn fetch_associations(recursive: bool) !Association;
fn fetch_leagues(association: Association, recursive: bool) !League;
fn fetch_matchday(league: League) !Matchday;

fn write_game_result(game: Game, game_number: u8, league: League) write_err!null;
