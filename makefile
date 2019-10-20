CC=lasm 
BIN=main.nes 
LST=main.sym

BINDIR=./bin
MAIN = main.asm

# main

nesblox: | init
	$(CC) -o$(BINDIR)/$(BIN) -l${BINDIR}/${LST} $(MAIN)

# other useful things

.PHONY: clean
clean:
	rm $(BINDIR)/*


.PHONY: setup
init:
	mkdir -p $(BINDIR)

