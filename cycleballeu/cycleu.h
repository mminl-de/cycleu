// This is the header file for cycleu
// see github.com/mminl-de/cycleu for more information

// TODO Can we just do that? Or could it be problematic
#include <stdint.h>
#include <time.h>
#include <stdbool.h>

enum AssociationType {Deutschland, Bayern, Brandenburg, BadenWuerttemberg, Hessen, RheinlandPfalz};
enum FetchStatus { Ok, AuthCodeWrong, LeagueUnknown, GameUnknown, Internet, CURL, OutOfMemory, JSONMisformated, Unknown };
enum URLProtocol {HTTPS};

typedef struct Address Address;
typedef struct Association Association;
typedef struct League League;
typedef struct Rank Rank;
typedef struct Matchday Matchday;
typedef struct Matchday_Team Matchday_Team;
typedef struct Matchday_Player Matchday_Player;
typedef struct Game Game;
typedef struct Team Team;
typedef struct Player Player;
typedef struct Club Club;
typedef struct Gym Gym;

struct Address {
	char *city;
	uint32_t zip;
	char *street;
};

struct Association {
	char *name_short;
	char *name_long;
	League *leagues;
	uint32_t league_n;
	Club *clubs;
	uint32_t club_n;
};

struct League {
	char *name_short;
	char *name_long;
	bool competitive;
	uint16_t season;
	struct {
		char *name;
		char *email;
		char *phone;
		Address address;
	} manager;
	Team *teams;
	uint8_t team_n;
	Rank *ranks;
	uint8_t rank_n;
	char *rules;
	uint8_t rule_n;
	time_t last_update;
};

// NOTE This is only used in League. The outside def. is needed to fetch its size with malloc
struct Rank {
	const char *team;
	uint8_t games_amount;
	uint16_t goals_plus;
	uint16_t goals_minus;
	uint16_t points;
	uint8_t rank;
};

struct Gym {
	char *name;
	char *phone;
	Address address;
};

struct Matchday {
	uint8_t number;
	time_t start;
	Gym gym;
	char *host_club_name;
	Matchday_Team *teams;
	uint8_t team_n;
	Game *games;
	uint8_t game_n;
};

struct Matchday_Team {
	char *name;
	bool present;
	Matchday_Player *players;
	uint8_t player_n;
};

struct Player {
	char *name;
	char *uci_code;
};

struct Matchday_Player {
	Player player;
	bool regular;
};

struct Game {
	uint8_t number;
	Matchday_Team *team_a;
	Matchday_Team *team_b;
	struct {
		uint8_t a;
		uint8_t b;
		struct {
			int8_t a;
			int8_t b;
		} half;
	} goals;
	bool is_writable;
};

struct Team {
	char *club_name;
	char *name;
	Player *players;
	uint8_t player_n;
};


struct Club {
	char *name;
	char *city;
	struct {
		char *name;
		char *email;
		char *phone;
		Address address;
	} contact;
	Gym *gyms;
	uint8_t gym_n;
};


bool cycleu_init();
enum FetchStatus cycleu_fetch_association(Association *association,
                                     enum AssociationType association_code,
                                     bool recursive);
enum FetchStatus cycleu_fetch_league(League *league,
                                enum AssociationType association_code,
                                char *league_name_unescaped,
                                bool base_infos_present,
                                bool recursive);
enum FetchStatus cycleu_fetch_matchday(Matchday *matchday,
                                  enum AssociationType association_code,
                                  char *league_name_unescaped,
                                  uint8_t number,
                                  bool recursive);
enum FetchStatus cycleu_write_result(Game game,
                                uint8_t game_number,
                                char *league_name_short,
                                char *association_name_short);
void cycleu_deinit();
// Not to use: receive_json
// TODO umbenennen?
