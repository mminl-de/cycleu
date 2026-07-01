const std = @import("std");

const print = std.debug.print;

const Matchday = struct {
	games: []Game,
	number: u8,
	gym: ?Gym,
	start: ?i64,
	end: ?i64,
};

const Game = struct {
	const Score = struct {
		t1: u8,
		t2: u8,
	};

	team1_idx: u8,
	team2_idx: u8,
	score: ?Score
};

const Team = struct {
	name: []const u8,
	players: []Player,
};

const Player = struct {
	name: []u8,
};

const Gym = struct {
	name: []u8,
	addr: struct {
		zip: [5] u8,
		city: []u8,
		street: []u8
	},
};

const League = struct {
	name: []const u8,
	matchdays: []Matchday,
	teams: []Team,
	last_update: i64,
};

var dbg_counter: [256]u32 = @splat(0);
fn dbg_print(id: u8) void {
	dbg_counter[id] += 1;
	print("[{d}]: Nr. {d}\n", .{id, dbg_counter[id]});
}

// AI generated
fn parse_date(date_str: []const u8) ?i64 {
	var parts = std.mem.splitScalar(u8, date_str, '.');
	const day = std.fmt.parseInt(u8, parts.next() orelse return null, 10) catch return null;
	const month = std.fmt.parseInt(u8, parts.next() orelse return null, 10) catch return null;
	const year = std.fmt.parseInt(u16, parts.next() orelse return null, 10) catch return null;

	// Calculate days since epoch (1970-01-01)
	var days: i64 = 0;

	// Add days for years
	var y: u16 = 1970;
	while (y < year) : (y += 1) {
		days += if (isLeapYear(y)) @as(i64, 366) else 365;
	}

	// Add days for months of current year
	const month_days = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
	for (month_days[0..month-1]) |md| {
		days += md;
	}
	if (month > 2 and isLeapYear(year)) {
		days += 1; // Leap day
	}

	// Add days of current month
	days += day - 1;

	return days * 86400;
}

fn isLeapYear(year: u16) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

fn idx_from_line(line: []const u8) !u8 {
	const start = (std.mem.find(u8, line, "[") orelse return error.Syntax) + 1;
	const end = std.mem.find(u8, line, "]") orelse return error.Syntax;
	if (start >= end) return error.Logic;
	return std.fmt.parseInt(u8, line[start .. end], 10) catch return error.Syntax;
}

fn num_val_from_line(line: []const u8) !i16 {
	const start = (std.mem.find(u8, line, "=") orelse return error.Syntax) + 1;
	const end = std.mem.findAny(u8, line, "\r\n ") orelse line.len;
	if (start >= end) return error.Logic;
	return std.fmt.parseInt(i16, line[start..end], 10) catch return error.Syntax;
}

fn str_val_from_line(allocator: std.mem.Allocator, line: []const u8) ![]const u8 {
	const start = (std.mem.find(u8, line, "\"") orelse return error.Syntax) + 1;
	const end = std.mem.findLast(u8, line, "\"") orelse return error.Syntax;
	if (start >= end) return error.Logic;
	return try allocator.dupe(u8, line[start .. end]);
}

fn game_idx_from_line(line: []const u8) !u8 {
	// all are maNUM[..., one of: ma/mb/ta/tb
	const start = 2;
	const end = std.mem.find(u8, line, "[") orelse return error.Syntax;
	if (start >= end) return error.Logic;
	return std.fmt.parseInt(u8, line[start .. end], 10) catch return error.Syntax;
}

fn team_from_str(allocator: std.mem.Allocator, input: []const u8) !Team {
	return .{
		.name = try str_val_from_line(allocator, input),
		.players = &.{}
	};
}

/// Game format from radball.at is:
/// ma1[2]=3 ==> Matchday 2, Game 1, Team A index is 3
/// mb1[2]=5 ==> Matchday 2, Game 1, Team B index is 3
/// ta1[2]=4 ==> Matchday 2, Game 1, Team A Score is 4
/// tb1[2]=6 ==> Matchday 2, Game 1, Team B Score is 6
fn game_from_str(input: []const u8) !?Game {
	var lines = std.mem.tokenizeAny(u8, input, "\r\n");

	// handle ma
	// We dont search for ma because ma is cut from the string with splitSequence
	// _ = std.mem.find(u8, line, "ma") orelse return error.Syntax;
	const ma = lines.next() orelse return error.Syntax;
	const team1_idx = try num_val_from_line(ma) - 1;
	
	// handle mb
	const mb = lines.next() orelse return error.Syntax;
	_ = std.mem.find(u8, mb, "mb") orelse return error.Syntax;
	const team2_idx = try num_val_from_line(mb) - 1;

	// If ma and mb are 0, the game is a filler, therefor we skip it
	if (team1_idx == team2_idx and team1_idx == -1) return null
	else if (team1_idx < 0 or team2_idx < 0) return error.Logic;
	

	// handle ta
	const ta = lines.next() orelse return error.Syntax;
	_ = std.mem.find(u8, ta, "ta") orelse return error.Syntax;

	const score1 = try num_val_from_line(ta);

	// handle tb
	const tb = lines.next() orelse return error.Syntax;
	_ = std.mem.find(u8, tb, "tb") orelse return error.Syntax;
	const score2 = try num_val_from_line(tb);

	// print("Game: ({}) {} - {} ({})\n", .{team1_idx, score1, score2, team2_idx});
	var score: ?Game.Score = undefined;
	if (score1 < -1 or score2 < -1) return error.Logic;
	if (score1 > -1 and score1 > -1) score = .{.t1 = @intCast(score1), .t2 = @intCast(score2)}
	else if (score1 == -1 and score2 == -1) score = null
	else if (score1 == -1 or score2 == -1) return error.Logic;
	return .{
		.team1_idx = @intCast(team1_idx),
		.team2_idx = @intCast(team2_idx),
		.score = score
	};
}

// input does not have to include "d1"
fn matchday_from_str(allocator: std.mem.Allocator, input: []const u8) !Matchday {
	// handle d1
	// We dont search for d1 because d1 is cut from the string with
	// splitSequence
	// _ = std.mem.find(u8, line, "d1") orelse return error.Syntax;
	// print("matchday_from_str:\n{s}", .{input});
	var lines = std.mem.tokenizeAny(u8, input, "\r\n");

	const d1 = lines.next() orelse return error.Syntax;
	const md_begin_str = try str_val_from_line(allocator, d1);
	const md_begin: ?i64 = parse_date(md_begin_str);

	// handle d2
	const d2 = lines.next() orelse return error.Syntax;
	_ = std.mem.find(u8, d2, "d2") orelse return error.Syntax;
	const idx = std.math.sub(u8, try idx_from_line(d2), 1) catch return error.Logic;

	const md_end_str = try str_val_from_line(allocator, d2);
	const md_end: ?i64 = parse_date(md_end_str);

	// Games
	if (lines.index+2 >= input.len) return error.Syntax;
	const games_str = input[lines.index+2..];
	var games = std.ArrayList(Game).empty;
	var games_it = std.mem.tokenizeSequence(u8, games_str, "ma");
	while (games_it.next()) |game_str| {
		// print("game: \n---{s}\n---\n", .{game_str});
		const g = try game_from_str(game_str) orelse continue;
		// TODO integrity checks
		// if (g.team1_idx >= teams.items.len) return error.Logic;
		// if (g.team2_idx >= teams.items.len) return error.Logic;
		try games.append(allocator, g);
	}
	// add Matchday
	return .{
		.games = try games.toOwnedSlice(allocator),
		.gym = null,
		.number = idx,
		.start = md_begin,
		.end = md_end,
	};
}

fn league_from_str(allocator: std.mem.Allocator, input: []const u8, league_name: []const u8) error{OutOfMemory, Syntax, Logic}!League {
    var teams = std.ArrayList(Team).empty;
	defer teams.deinit(allocator);
    var matchdays = std.ArrayList(Matchday).empty;
	defer matchdays.deinit(allocator);

	const start = std.mem.find(u8, input, "team[1") orelse return error.Syntax;
	const end = std.mem.find(u8, input, "function") orelse return error.Syntax;
	const trimmed = input[start .. end];

	const team_end = std.mem.find(u8, trimmed, "d1") orelse return error.Syntax;
	const team_str = trimmed[0 .. team_end];
	var team_it = std.mem.tokenizeAny(u8, team_str, "\r\n");
	while(team_it.next()) |line| {
		_ = std.mem.find(u8, line, "team[") orelse return error.Syntax;

		const idx = std.math.sub(u8, try idx_from_line(line), 1) catch return error.Logic;
		if (teams.items.len != idx) return error.Logic;

		const team = try team_from_str(allocator, line);
		try teams.append(allocator, team);
	}

	// Matchdays
	const matchdays_str = trimmed[team_end ..];
	// print("matchdays_str:\n{s}", .{matchdays_str});
	var matchdays_it = std.mem.tokenizeSequence(u8, matchdays_str, "d1");

	while(matchdays_it.next()) |md_str| {
		const md = try matchday_from_str(allocator, md_str);
		try matchdays.append(allocator, md);
		// print("ADDED MATCHDAY, now: {d}", .{matchdays.items.len});
	}

	const league: League = .{ 
		.teams = try teams.toOwnedSlice(allocator),
		.last_update = 0,
		.matchdays = try matchdays.toOwnedSlice(allocator),
		.name = league_name
	};
	return league;
}

const analyze_file_error = error {
	FileTooBig,
	OutOfMemory,
	Syntax,
	Logic
} || std.Io.File.OpenError || std.Io.File.ReadPositionalError;
fn analyze_file(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, filename: []const u8) analyze_file_error!League{
	const file = try dir.openFile(io, filename, .{});

	// This max is arbitrary and probably way too big
	var buf: [1024 * 1024]u8 = undefined;
	const bytes_read = try file.readPositionalAll(io, &buf, 0);
	if (bytes_read == buf.len) return error.FileTooBig;

	const name = std.fs.path.stem(filename);
	return try league_from_str(allocator, &buf, name);
}

fn analyze_dir(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]League {
	const dir = try std.Io.Dir.openDirAbsolute(io, path, .{.iterate = true});
	defer dir.close(io);
	var dir_iter = dir.iterate();

    var leagues = std.ArrayList(League).empty;
    var leagues_futures = std.ArrayList(std.Io.Future(analyze_file_error!League)).empty;

	while (try dir_iter.next(io)) |entry| {
		if (entry.kind != std.Io.File.Kind.file) continue;
		const name = try allocator.dupe(u8, entry.name);
		const league_fut = try io.concurrent(analyze_file, .{allocator, io, dir, name});

		try leagues_futures.append(allocator, league_fut);
	}
	for(0..leagues_futures.items.len) |i| {
		var fut = leagues_futures.items[i];
		const league = fut.await(io) catch |e| {
			std.debug.print("WARN: failed to analyze something with {}\n", .{e});
			continue;
		};
		try leagues.append(allocator, league);
	}
	return leagues.toOwnedSlice(allocator);
}

fn print_league(league: League) !void {
	print("*****************************************\n", .{});
	print("League: '{s}'\n", .{league.name});
	print("Matchdays:\n", .{});
	for (league.matchdays) |md| {
		print("*** Matchday: {}\n", .{md.number});
		for (md.games, 0..) |g, i| {
			var buf1: [3]u8 = undefined;
			var buf2: [3]u8 = undefined;
			
			var s1: []const u8 = "?";
			var s2: []const u8 = "?";

			if (g.score) |score| {
				s1 = try std.fmt.bufPrint(&buf1, "{d}", .{score.t1});
				s2 = try std.fmt.bufPrint(&buf2, "{d}", .{score.t2});
			}
			print("{d}: {s} --- {s} : {s} --- {s}\n", .{i, league.teams[g.team1_idx].name, s1, s2, league.teams[g.team2_idx].name});
		}
		print("******************\n", .{});
	}
	print("*****************************************\n", .{});
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

	const leagues = try analyze_dir(allocator, init.io, "/home/mrmine/prg/cycleu/radballat/radball.at/https:/www.vfh-muecheln.de/2026/Ergebnisse/Deutschland/Meisterschaft");

	for(leagues) |league|
		try print_league(league);
	return;
}
