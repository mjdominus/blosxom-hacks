
URL=http://web.archive.org/web/20071216004854/http://blog.plover.com/2007/
#URL=http://web.archive.org/web/20080504131009/http://blog.plover.com/2008/

diff: d0 d1
	-diff -u d0 d1 > diff

d0: d.bkp
	localtime < d.bkp > d0

d1: .dates.fixed
	localtime < dates > d1

.dates.fixed: fixdates
	perl fixdates $(URL)
	sort -k 2 -o dates dates
	@touch .dates.fixed


