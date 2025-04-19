const std = @import("std");

void help();
int read(int argc, char *argv[]);
int write(int argc, char *argv[]);
int str_to_uint(char *str);

pub fn main() u8 {
	if(argc < 2){
		help();
		return 1;
	}
	if(!strcmp(argv[1], "read"))
		return read(argc-2, &argv[2]);
	else if(!strcmp(argv[1], "write"))
		return write(argc-2, &argv[2]);
	else {
		help();
		return 1;
	}
}

//@ret arg number in argv or -1
int is_arg(char arg[], int argc, char *argv[]){
	for(int i=0; i < argc; i++)
		if(!strcmp(arg, argv[i]))
			return true;
	return false;
}

int read(int argc, char *argv[]){
	int verband_arg_ind = is_arg("-verband", argc, argv);
	if(verband_arg_ind == -1){
		printf("SYNTAX: You need to specify a Verband\n");
		help(); return 1;
	}
	if(argv[verband_arg_ind][0] == '-'){
		printf("SYNTAX: -verband {Verbandskürzel} Verbandskürzel is needed!");
		help(); return 1;
	}
	int staffel_arg_ind = is_arg("-staffel", argc, argv);
	if(staffel_arg_ind == -1){
		printf("SYNTAX: You need to specify a Staffel!\n");
		help(); return 1;
	}
	if(argv[verband_arg_ind][0] == '-'){
		printf("SYNTAX: -staffel {staffelkürzel} Staffelkürzel is needed!");
		help(); return 1;
	}
	// Now there are 3 options: -spieltag, -metainfos, -tabelle
	int spieltag_arg_ind = is_arg("-spieltag", argc, argv);
	if(spieltag_arg_ind != -1){
		//TODO Safely convert string into int and error if its a nonint
		if(argc < spieltag_arg_ind+2){
			printf("SYNTAX: -spieltag {n} n is needed!\n");
			help(); return 1;
		}
		int spieltag_ind = str_to_uint(argv[spieltag_arg_ind+1]);
		if(spieltag_ind < 0){
			printf("SYNTAX: -spieltag {n} n has to be a positive integer\n");
			help(); return 1;
		}
		// Now there are 3 options: -spiel, -teams, -metainfos

	}

	return 0;
}

int write(int argc, char *argv[]){
	return 0;
}

int str_to_uint(char *str){
	return 0;
}


void help() {
	printf(
		"Syntax: Go recursive with these options. No going back. For more help and examples see the man page\n"
		"cycleball.eu-cli {read, write} {args}\n\n"

		"READ ARGS:\n"
		"Verbände: -verband {Verbandskürzel}\n"
		"Staffel: -staffel {staffelskürzel}\n"
		"-Spieltag: -spieltag {Spieltagsnummer}\n"
		"--Spiel: -spiel {Spielnummer}\n"
		"---score(entweder t1 oder t2): -score {t1} {t2}\n"
		"---halftimescore(entweder t1 oder t2): -htscore {t1} {t2}\n"
		"---team(entweder t1 oder t2): -team {t1} {t2}\n"
		"--teams(if a number is passed as arg only that team is used): -teams {n}\n"
		"---player(only ok if a number was passed in teams): -player {1/2}\n"
		"--metainfos: -metainfos\n"
		"---time: -time\n"
		"---ort: -ort\n"
		"---telefon: -telefon\n"
		"-metainfos: -metainfos\n"
		"--anmerkungen: -anmerkungen\n\n"
		"--staffelleiter: -staffelleiter\n"
		"---name: -name\n"
		"---email: -email\n"
		"---ort: -ort\n"
		"---telefon: -telefon\n"
		"--teams(if a number is passed as arg only that team is used): -teams {n}\n"
		"---player(only ok if a number was passed in teams): -player {1/2}\n"
		"-tabelle: -tabelle\n"
		"--platz: -platz {n}\n"
		"---teamname: -teamname\n"
		"---games: -games\n"
		"---goalsPlus: -goalPlus\n"
		"---goalsMinus: -goalMinus\n"
		"---goalsDiff: -goalDiff\n"
		"---points: -points\n"

		"Use offline database(create also updates): -offline {use, delete, create}\n\n"

		"WRITE ARGS:\n"
		"Verbände: -verband {Verbandskürzel}\n"
		"Staffel: -staffel {staffelskürzel}\n"
		"Spieltag: -spieltag {Spieltagsnummer}\n"
		"Spiel: -spiel {Spielnummer}\n"
		"-score(entweder t1 oder t2): -score {t1} {t2}\n"
		"-halftimescore(entweder t1 oder t2): -htscore {t1} {t2}\n"

	);
}
