SRC ?= lib.zig
NAME ?= cycleu
OUT_DIR ?= out/lib$(NAME).so
DOCS_DIR ?= docs/

install:
	zig build-lib \
		--name $(NAME) \
		-femit-bin=$(OUT_DIR) \
		-femit-docs=$(DOCS_DIR) \
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

test_mem_leaks:
	export CYCLEU_TEST_MEMLEAKS=1

test:
	zig test \
		-I /usr/include \
		-L /usr/lib \
		-lc \
		-lcurl \
		$(SRC)
	unset CYCLEU_TEST_MEMLEAKS
