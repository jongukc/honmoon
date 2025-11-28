SUBDIRS := alias remap

.PHONY: all clean $(SUBDIRS)

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $(abspath ../linux-l1) M=$(abspath ./$@) CC=$(CC) modules

clean:
	$(RM) compile_commands.json
	for d in $(SUBDIRS); do \
		$(MAKE) -C $$d clean || true; \
		$(MAKE) -C $(abspath ../linux-l1) M=$(abspath ./$$d) clean || true; \
	done
