SRC ?= lib.zig
NAME ?= cycleu
OUT_DIR ?= out/lib$(NAME).so

install:
	zig build-lib \
		--name $(NAME) \
		-femit-bin=$(OUT_DIR) \
		-target native-native-gnu \
		-dynamic \
		-O ReleaseFast \
		-I /usr/include \
		-lc \
		$(SRC)

debug:
	zig build-lib \
		--name $(NAME) \
		-femit-bin=$(OUT_DIR) \
		-target native-native-gnu \
		-dynamic \
		-I /usr/include \
		-lc \
		$(SRC)
