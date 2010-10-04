.PHONY: all clean

CTEX=pdflatex
FLAGS=--interaction nonstopmode
IMG=img/ensimag.png img/thales_avionics.png
DEPS=$(IMG)
LOG=/dev/null

.PHONY: clean all


all: rapport_thales.pdf

%.pdf: %.tex $(DEPS)
	@(echo -n "Compilation du rapport $*...")
	@($(CTEX) $(FLAGS) $< > $(LOG) || echo "[FAIL]" && exit)
	@($(CTEX) $(FLAGS) $< > $(LOG) || echo "[FAIL]" && exit)
	@($(CTEX) $(FLAGS) $< > $(LOG) || echo "[FAIL]" && exit)
	@(rm -f $*.{aux,toc,log,out})
	@(echo "[DONE]")

clean:
	@(echo -n "Suppress all generated pdf files...")
	@(rm *.pdf 2> $(LOG) || echo -n " No pdf files...")
	@(echo "[DONE]")
