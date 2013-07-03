V=06042013

PREFIX = /usr

install:
	install -dm755 $(DESTDIR)$(PREFIX)/share/pacman/keyrings
	install -m0644 archbsd.gpg $(DESTDIR)$(PREFIX)/share/pacman/keyrings/
	install -m0644 archbsd-trusted $(DESTDIR)$(PREFIX)/share/pacman/keyrings/


uninstall:
	rm -f $(DESTDIR)$(PREFIX)/share/pacman/keyrings/archbsd{.gpg,-trusted}
	rmdir -p --ignore-fail-on-non-empty $(DESTDIR)$(PREFIX)/share/pacman/keyrings/

dist:
	mkdir archbsd-keyring-$(V)
	cp -rv Makefile archbsd-trusted archbsd.gpg master master-keyids packager packager-keyids update-keys archbsd-keyring-$(V)
	tar -cvzf archbsd-keyring-$(V).tar.gz archbsd-keyring-$(V)/
	gpg --detach-sign --use-agent archbsd-keyring-$(V).tar.gz

.PHONY: install uninstall dist
