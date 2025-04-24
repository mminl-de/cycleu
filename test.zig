const std = @import("std");

const print = std.debug.print;


test {
    const cycleu = @import("lib.zig");

    const Association = cycleu.Association;
    const AssociationType = cycleu.AssociationType;
    const FetchStatus = cycleu.FetchStatus;
    const League = cycleu.League;
    const Matchday = cycleu.Matchday;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer switch (gpa.deinit()) {
        .leak => print("Leaks :(\n", .{}),
        .ok => print("No leaks :)\n", .{})
    };
    const allocator = gpa.allocator();

    _ = cycleu.cycleu_init();
    defer cycleu.cycleu_deinit();

    var ass_decoy: Association = undefined;
    var ret_val = cycleu.cycleu_fetch_association(&ass_decoy, AssociationType.Deutschland, false);
    if (ret_val != FetchStatus.Ok) {
        if (ret_val == FetchStatus.JSONMisformated)
            print("Json was misformated. Fuck you\n", .{});
        return;
    }
    defer ass_decoy.deinit();
    
    print("league {d}: {s} ({s})\n", .{1, ass_decoy.leagues[1].name_long, ass_decoy.leagues[1].name_short});

    var league_decoy: League = undefined;
    ret_val = cycleu.cycleu_fetch_league(&league_decoy, AssociationType.Deutschland, "b11", false, false);
    if (ret_val != FetchStatus.Ok) {
        if (ret_val == FetchStatus.JSONMisformated)
            print("Json was misformated. Fuck you\n", .{});
        return;
    }
    defer league_decoy.deinit();

    var matchday_decoy: Matchday = undefined;
    ret_val = cycleu.cycleu_fetch_matchday(&matchday_decoy, AssociationType.Deutschland, "b11", league_decoy, 1, false);
    if (ret_val != FetchStatus.Ok) {
        if (ret_val == FetchStatus.JSONMisformated)
            print("Json was misformated. Fuck you\n", .{});
        return;
    }

    for (league_decoy.ranks[0..league_decoy.rank_n], 0..) |rank, i| {
        print("{d:2}: {s:30}, {d}, {d:>3}:{d:<3}, {d}\n", .{i, rank.team.name, rank.games_amount, rank.goals_plus, rank.goals_minus, rank.points});
    }
    
    for (matchday_decoy.games[0..matchday_decoy.game_n], 0..) |game, i| {
        print("{d:2}.) {s:>20} {d:>2}:{d:<2} {s:<20}\n", .{i, game.team_a.orig_team.name, game.goals.a, game.goals.b, game.team_b.orig_team.name});
    }

    //for (ass_decoy.leagues[1].teams[0..ass_decoy.leagues[1].team_n], 0..) |team, i| {
    //    print("Team {d}: {s}\n", .{i, team.name});
    //}
}
