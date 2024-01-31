def user_ok(task,user)
  resp = Typhoeus.get(task['orgmodel'])
  xml = resp.body
  orgmodel = XML::Smart.string(xml)
  orgmodel.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
  subjects = orgmodel.find('/o:organisation/o:subjects/o:subject')
  unit = task['unit']
  role = task['role']
  if (unit=='*')
    if (role=='*')
      subjects.each{|s| return true if s.attributes['uid']==user}
    else
      orgmodel.find("/o:organisation/o:subjects/o:subject[o:relation/@role='#{role}']").each do |s|
				return true if user==s.attributes['uid']
			end
		end
	else
		if (role=='*')
			orgmodel.find("/o:organisation/o:subjects/o:subject[o:relation/@unit='#{unit}']").each do |s|
        return true if user==s.attributes['uid']
      end
		else
			orgmodel.find("/o:organisation/o:subjects/o:subject[o:relation/@unit='#{unit}' and o:relation/@role='#{role}']").each do |s|
      	return true if user==s.attributes['uid']
      end
    end
  end
  false
end

def user_info(task,user)
  orgmodel = XML::Smart.open_unprotected(task['orgmodel'])
  orgmodel.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
  user = orgmodel.find("/o:organisation/o:subjects/o:subject[@uid='#{user}']/o:relation")
  {}.tap{ |t| user.map{|u| (t[u.attributes['unit']]||=[]) <<  u.attributes['role']}}
end

