const std = @import("std");

const err = error {ARG_NOT_FOUND};

pub fn main() u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const args = std.process.argsAlloc(allocator) catch return 1;
    defer std.process.argsFree(allocator, args);
    const verband_arg_ind = arg_ind(args, "-verband") catch fail("SYNTAX: -verband is needed!\n");
    const staffel_arg_ind = arg_ind(args, "-staffel") catch fail("SYNTAX: -staffel is needed!\n");
    if (arg_ind(args, "-spieltag")) |spieltag_arg_ind| {
        if (arg_ind(args, "-spiel")) |spiel_arg_ind| {
            if(arg_ind(args, "-score")) |score_arg_ind| {}
            else if(arg_ind(args, "-htscore")) |htscore_arg_ind| {}
            else if(arg_ind(args, "-team")) |team_arg_ind| {}
        } else if(arg_ind(args, "-teams")) |teams_arg_ind| {
            if(arg_ind(args, "-player")) |player_arg_ind| {}
        } else if(arg_ind(args, "-spieltagdaten")) {
            if(arg_ind(args, "-time")) {}
            else if(arg_ind(args, "-ort")) {}
            else if(arg_ind(args, "-telefon")) {}
        }
    } else if(arg_ind(args, "-metainfos")) {
        if(arg_ind(args, "-anmerkungen")) {
        } else if(arg_ind(args, "-staffelleiter")) {
            if(arg_ind(args, "-name")) {}
            else if(arg_ind(args, "-email")) {}
            else if(arg_ind(args, "-ort")) {}
            else if(arg_ind(args, "-telefon")) {}
        } else if(arg_ind(args, "-teams")) {
            if(arg_ind(args, "-player")) |player_arg_ind| {}
        }
    } else if(arg_ind(args, "-tabelle")) {
        if(arg_ind(args, "-platz")) |platz_arg_ind| {
            if(arg_ind(args, "-teamname")) {}
            else if(arg_ind(args, "-games")) {}
            else if(arg_ind(args, "-goals_plus")) {}
            else if(arg_ind(args, "-goals_minus")) {}
            else if(arg_ind(args, "-goals_diff")) {}
            else if(arg_ind(args, "-points")) {}
        }
    }
}

//@ret arg number in argv or -1
fn arg_ind(args: [][]u8, str: [] const u8) !u8 {
    for(args, 0..) |arg, i|
        if(std.mem.eql(u8, arg, str))
            return i;
    return err.ARG_NOT_FOUND;
}

fn help() void {
	std.debug.print(
\\Syntax: Go recursive with these options. No going back. For more help and examples see the man page
\\cycleball.eu-cli {read, write} {args}
\\
\\READ ARGS:
\\Verbände: -verband {Verbandskürz
\\Staffel: -staffel {staffelskürz
\\-Spieltag: -spieltag {Spieltagsnumm
\\--Spiel: -spiel {Spielnumm
\\---score(entweder t1 oder t2): -score {t1} {
\\---halftimescore(entweder t1 oder t2): -htscore {t1} {
\\---team(entweder t1 oder t2): -team {t1} {
\\--teams(if a number is passed as arg only that team is used): -teams 
\\---player(only ok if a number was passed in teams): -player {1
\\--spieltagdaten: -spieltagdaten
\\---time: -time
\\---ort: -ort
\\---telefon: -telefon
\\-metainfos: -metainfos
\\--anmerkungen: -anmerkungen
\\--staffelleiter: -staffelleiter
\\---name: -name
\\---email: -email
\\---ort: -ort
\\---telefon: -telefon
\\--teams(if a number is passed as arg only that team is used): -teams 
\\---player(only ok if a number was passed in teams): -player {1/2}
\\-tabelle: -tabelle
\\--platz: -platz
\\---teamname: -teamname
\\---games: -games
\\---goals_plus: -goal_plus
\\---goals_minus: -goal_minus
\\---goals_diff: -goal_diff
\\---points: -points
\\
\\Use offline database(create also updates): -offline {use, delete, create}
\\WRITE ARGS:
\\Verbände: -verband {Verbandskürzel}
\\Staffel: -staffel {staffelskürzel}
\\Spieltag: -spieltag {Spieltagsnummer}
\\Spiel: -spiel {Spielnummer}
\\-score(entweder t1 oder t2): -score {t1} {t2}
\\-halftimescore(entweder t1 oder t2): -htscore {t1} {t2}
, .{});
}

fn fail(err_msg: []const u8) void {
    std.debug.print(err_msg, .{});
    help();
    std.process.exit(1);
}
