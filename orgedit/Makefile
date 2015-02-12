%.flower.html: %.xml
	ruby orbitflower.rb $<
%.list.html: %.xml
	ruby orbitlist.rb $<
%.nodelink.html: %.xml
	ruby nodelink.rb $<

FILES = organisation_eight.xml organisation_informatik.xml organisation_reactor.xml organisation_root.xml organisation_studentmanagement.xml organisation.xml

default: files

files: $(FILES:.xml=.flower.html) $(FILES:.xml=.list.html) $(FILES:.xml=.nodelink.html)

clean:
	$(RM) *.class
