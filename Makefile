SRC ?= lib.zig
NAME ?= cycleu
OUT_DIR ?= out/lib$(NAME).so
DOCS_DIR ?= docs/
TEST_LEAKS ?= 0

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

test:
	@[ "$(TEST_LEAKS)" = "1" ] && export CYCLEU_TEST_MEMLEAKS=1; \
	zig test \
		-I /usr/include \
		-L /usr/lib \
		-lc \
		-lcurl \
		$(SRC)
