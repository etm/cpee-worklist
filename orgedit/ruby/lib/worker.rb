### All code in this file is provided under the LGPL license. Please read the file COPYING.
require File.expand_path(File.dirname(__FILE__) + '/utils')
require File.expand_path(File.dirname(__FILE__) + '/node')
require File.expand_path(File.dirname(__FILE__) + '/subject')

RNG = File.expand_path(File.dirname(__FILE__) + '/organisation.rng')

class GraphWorker
  attr_reader :nodes, :paths, :roots, :subjects, :maxsubjects

  def initialize(file,xpath,subjects,nopts)
    ### build node list with string ids referencing parents # {{{
    @nodes = []
    schema = XML::Smart.open(RNG)
    XML::Smart.open(file) do |doc|
      unless doc.validate_against(schema)
        puts "Not a valid organisation file" 
      end
      doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0' 
      doc.find(xpath).each do |ru|
        type = ru.qname.to_s.to_sym
        id = ru.attributes['id'].to_s

        node = Node.new(id,type,nopts)
        node.numsubjects = doc.find("count(#{subjects.sub(/\/*$/,'')}[o:relation[@#{type}=\"#{id}\"]])").to_i
        @nodes << node
        ru.find('o:parent').each do |pa|
          ru.find("../*[@id=\"#{pa.to_s}\"]").each do |pid|
            node.parents << [type, pa.to_s]
          end  
        end
      end  
      
      node = Node.new("add","add",nopts)
      node.numsubjects = @nodes.map{|n| n.numsubjects}.inject(:+)/@nodes.length
      @nodes << node

      ### subjects
      @subjects = []
      doc.find("#{subjects.sub(/\/*$/,'')}").each do |u|
        subject = Subject.new(u.attributes['id'].to_s)
        u.find("o:relation").each do |r|
          unit = nodes.find{|n| n.id == r.attributes['unit'].to_s}
          role = nodes.find{|n| n.id == r.attributes['role'].to_s}
          if unit.nil?
            p r.attributes['unit']
          end  

          unit.subjects.push(subject).uniq!
          role.subjects.push(subject).uniq!
          subject.relations << Relation.new(unit,role) if !unit.nil? && !role.nil? && unit.type == :unit && role.type == :role
        end
        @subjects << subject
      end
    end # }}}

    ### replace string ids with references to actual parent nodes # {{{
    @maxsubjects = 0
    @nodes.each do |n|
      @maxsubjects = n.numsubjects if @maxsubjects < n.numsubjects
      unless n.parents.empty?
        tparents = []
        n.parents.each do |p|
          if tnode = @nodes.find{|no| no.type == p[0] && no.id == p[1] }
            tparents << tnode 
          end  
        end
        n.parents = tparents
      end  
    end # }}}

    ### calculate paths through graphs # {{{
    @paths = []
    @nodes.each do |n|
      @paths << [n]
      calculate_path(@paths,@paths.last)
    end # }}}

    ### move nodes of two paths to a list whenever there are common nodes # {{{
    groups = calculate_groups(@paths)
    ### repeat, as after first run, groups may further overlap 
    ### example [a,b], [c,d], [c,d,a] => [a,b], [c,d,a] => [a,b,c,d]
    while groups.length > (tgroups = calculate_groups(groups)).length
      groups = tgroups
    end # }}}

    ### add group ids to nodes # {{{
    groups.each_with_index do |g,i|
      @nodes.each do |n|
        n.group = i if g.include?(n)
      end
    end # }}}

    ### root candidates # {{{
    @roots = []
    @paths = @paths.sort{|a,b| [a[0].group,b.length] <=> [b[0].group,a.length]}
    grouproots = []
    @paths.each do |p|
      grouproots[p[0].group] ||= p.length
      if grouproots[p[0].group] == p.length
        @roots << p.last
      end  
    end
    @roots.uniq! # }}}
  end

  def rank_short!# {{{
    @paths.each do |pa|
      ndx = 1
      if pa.length == @paths[0].length
        pa.reverse.each do |e|
          e.rank = ndx if e.rank > ndx || e.rank == 0
          ndx += 1
        end
      else
        pa.reverse.each do |e|
          if e.rank == 0
            e.rank = ndx
            ndx += 1
          else
            ndx = e.rank + 1
          end
        end
      end
    end
    @nodes = @nodes.sort_by{|a| [a.group,a.rank] }
  end  # }}}

  def rank_long!# {{{
    @paths.each do |pa|
      ndx = 1
      pa.reverse.each do |e|
        if e.rank == 0
          e.rank = ndx
          ndx += 1
        else
          ndx = e.rank + 1
        end  
      end
    end
    @nodes = @nodes.sort_by{|a| [a.group,a.rank] }
  end  # }}}

  def debug# {{{
    deb = ''
    deb << "---Group => Length: Path" + "-" * 20 + "\n"
    @paths.each do |p|
      deb << p[0].group.to_s + " => " + p.length.to_s + ": " + p.map{|o|o.id}.join('->') + "\n"
    end

    deb << "---Root Candiadates-----" + "-" * 20 + "\n"
    @roots.each do |r|
      deb << r.id + "\n"
    end

    deb << "---Rank-----------------" + "-" * 20 + "\n"
    @nodes.sort{|a,b|a.rank<=>b.rank}.each do |e|
      deb << "#{e.id} => #{e.rank}" + "\n"
    end
    deb
  end# }}}

private
  def calculate_path(paths,path)
    parents = path.last.parents
    case parents.length
      when 0
      when 1 
        return if path.include?(parents[0])
        path << parents[0]
        calculate_path(paths,path)
      else
        tpath = path.dup
        parents.each do |p|
          next if tpath.include?(p)
          if p == parents.first
            path << p
            calculate_path(paths,path)
          else  
            paths << (tpath.dup << p)
            calculate_path(paths,paths.last)
          end  
        end  
    end    
  end

  def calculate_groups(what)
    groups = []
    tpath = []
    what.each do |path|
      if (path & tpath).any?
        tpath = (tpath + path).uniq
        groups[groups.length-1] = tpath
      else
        groups << path
        tpath = path
      end
    end
    groups
  end  

end
