CC=lasm 
BIN=main.bin 
LST=main.sym

BINDIR=./bin
MAIN = main.asm

# main

nesrpg: | init
	$(CC) -o$(BINDIR)/$(BIN) -l${BINDIR}/${LST} $(MAIN)

# other useful things

.PHONY: clean
clean:
	rm $(BINDIR)/*


.PHONY: setup
init:
	mkdir -p $(BINDIR)

