--Q1:

drop type if exists RoomRecord cascade;
create type RoomRecord as (valid_room_number integer, bigger_room_number integer);
create or replace function q1(course_id integer) 
	returns RoomRecord
	as $$
	declare 
		enrolnumber integer :=0;
		waitnumber integer :=0;
		r record;
		allnumber integer:=0;
		valid_room_number integer :=0;
		bigger_room_number integer:=0;
		roomrecord RoomRecord;
		begin
			for r in 
			select student from course_enrolments where course = course_id
			LOOP
				enrolnumber := enrolnumber + 1;
			end loop;
			for r in 
			select student from course_enrolment_waitlist where course = course_id 
			LOOP
				waitnumber :=waitnumber + 1;
			end loop;
			allnumber := waitnumber + enrolnumber;
			for r in
			select id,capacity from rooms 
			LOOP
				if (r.capacity >= enrolnumber) then 
					valid_room_number := valid_room_number +1;
				end if; 
				if (r.capacity >= allnumber) then 
					bigger_room_number := bigger_room_number +1;
				end if;
			end loop;
			roomrecord.valid_room_number:=valid_room_number;
			roomrecord.bigger_room_number:=bigger_room_number;
			return roomrecord;
		end;
	$$ language plpgsql;


--Q2:

drop type if exists TeachingRecord cascade;
create type TeachingRecord as (cid integer, term char(4), code char(8), name text, uoc integer, average_mark integer, highest_mark integer, median_mark integer, totalEnrols integer);

create or replace function Q2(staff_id integer)
	returns setof TeachingRecord
	as $$
		declare
		tr TeachingRecord;
		r integer;
		exist integer;
		begin
		SELECT INTO exist id FROM staff WHERE id=$1;
        IF NOT FOUND THEN
        RAISE EXCEPTION 'INVALID STAFFID';
        END IF;
		for r in select * from course($1) loop
			tr.cid:=r;
			tr.term:=semester(r);
			select into tr.code (subject(r)).code from subject(r);
			select into tr.name (subject(r)).name from subject(r);
			select into tr.uoc  (subject(r)).uoc  from subject(r);
			select into tr.average_mark (scoreselect(r)).average_mark from scoreselect(r);
			select into tr.highest_mark (scoreselect(r)).highest_mark from scoreselect(r);
			select into tr.median_mark  (scoreselect(r)).median_mark from scoreselect(r);
			select into tr.totalEnrols  (scoreselect(r)).enrolments from scoreselect(r);
			return next tr;
		end loop;
		end;
	$$ language plpgsql;


---选出所有课程
create or replace function course(staff_id integer)
	returns setof integer
	as $$
		begin
			return query
			select course from course_staff where staff=staff_id and enrolment(course)<>0;
		end;		
	$$ language plpgsql;	
--保证选课人数不为0，并返回选课人数	
create or replace function enrolment(courseid integer)
	returns  integer
	as $$
	declare 
		r record;
		count integer:=0;		
		begin
			for r in 
			select student from course_enrolments where course=$1
			loop
			count:=count + 1;
			end loop;
			return count;
		end;		
	$$ language plpgsql;
--找出课程学期 输出（'XXS1'）
create or replace function semester(courseid integer)
	returns char(4)
	as $$
		declare
		semesterid integer;
		y char(2);
		y1 text;
		t char(2);
		begin
			select into semesterid semester from courses where id=$1;
			select into y1 to_char(year,'9999') from semesters where semesters.id = semesterid;
			select into t lower(term) from semesters where semesters.id = semesterid;
			return substr(y1,4,length(y1))||t;
		end;		
	$$ language plpgsql;
--subject code名称和uoc
drop type if exists subjectrecord cascade;
create type subjectrecord as (code char(8),name MediumName, uoc integer);
create or replace function subject(courseid integer)
	returns  subjectrecord
	as $$
	declare 
		subr subjectrecord;
		subid integer;
		nm MediumName;
		credit integer;
		cd char(8);
		begin
		select into subid subject from courses where id = $1;
		select into nm name from subjects where id = subid; 
		select into credit uoc from subjects where id =subid;
		select into cd code from subjects where id =subid;
		subr.name:=nm;
		subr.code:=cd;
		subr.uoc:=credit;
		return subr;		
		end;		
	$$ language plpgsql;
---平均分、中位数、最高分,选课人数
drop type if exists scores cascade;
create type scores as (average_mark integer,highest_mark integer,median_mark integer,enrolments integer);
create or replace function scoreselect(courseid integer)
	returns scores
	as $$
		declare
		score scores;
		count integer:=0;
		sum integer:=0;
		hs integer:=0;
		r integer;
		counta integer:=0;
		enda integer:=0;
		endb integer:=0;
		mediana integer;
		medianb integer;
		finmedian integer;
 		begin
		for r in 
		select mark from course_enrolments where course=$1 
		loop
			if r is not null then 
				count:=count+1;
				sum:=sum+r;
				if r>hs then 
				hs :=r;
				end if;	
			end if;
		end loop;
		score.average_mark:=round(sum::numeric/count::numeric,0);
		score.highest_mark:=hs;
		score.enrolments:=count;
		if count % 2 =0 then 
			enda := count/2;
			endb := count/2 +1;
		else
			endb := count/2 +1;
		end if;		
		for r in 
		select mark from course_enrolments where course=$1 order by mark
		loop
			if r is not null then
			counta:=counta+1;
				if enda <>0 and counta=enda then
					mediana:=r;
				end if;
				if endb <>0 and counta=endb then
					medianb:=r;
				end if;
			end if ;
		end loop;
		if enda<>0 then 
		finmedian:= round((mediana::numeric + medianb::numeric)/2::numeric,0);
		else
		finmedian:=medianb;
		end if;
		score.median_mark:=finmedian;
		return score;
		end;
	$$ language plpgsql;


--Q3:

drop type if exists CourseRecord cascade;
create type CourseRecord as (unswid integer, student_name text, course_records text);

create or replace function Q3(org_id integer, num_courses integer, min_score integer)
  returns setof CourseRecord
as $$
	declare
		stu integer;
		result CourseRecord;
		corse integer;
		exist integer;
	begin
		SELECT INTO exist id FROM orgunits WHERE id=$1;
        IF NOT FOUND THEN
			RAISE EXCEPTION 'INVALID ORGID';
        END IF;
		for stu in 
		select a.student from allstudent($1,$2)as a,q3selectstu($1,$3) as b where a.student=b.student loop
			select into result.unswid (stuinfo(stu)).unswid from stuinfo(stu);
			select into result.student_name (stuinfo(stu)).name from stuinfo(stu);
			select into result.course_records infodisplay(stu,$1);
			return next result;
		end loop;		
	end;
$$ language plpgsql;
----所有机构及子机构
create or replace function allorg(org_id integer)
	returns setof integer
as $$
	declare
	org integer;
	begin
	for org in 
	(with recursive allorg as 
	(select ou.member from orgunit_groups as ou where ou.owner=$1
		union all
	select o.member from orgunit_groups as o, allorg where o.owner = allorg.member and o.owner <> o.member )
	select * from allorg)loop
	return next org;
	end loop;
	end;
$$ language plpgsql;

--选出学生以及在该院系选课的数目>num_courses
drop type if exists twointegers cascade;
create type twointegers as (student integer,numbers integer);
create or replace function allstudent(org_id integer,num_courses integer)
	returns setof twointegers
as $$
	declare	
	begin
	return query
	select student,(count(*)::integer)  from course_enrolments where course in (
	select id from courses where subject in (select id from subjects where offeredby in (select * from allorg($1))) ) group by student having count(*)>$2;	
	end;
$$ language plpgsql;
---通过学生id 选出姓名和unswid
drop type if exists studentinfo cascade;
create type studentinfo as (unswid integer,name LongName);
create or replace function stuinfo(student_id integer)
	returns  studentinfo
as $$
declare
	studinfo studentinfo;
	begin
	select into studinfo.unswid unswid from people where id=$1;
	select into studinfo.name name from people where id=$1;	
	return studinfo;
	end;
$$ language plpgsql;

--按照course返回subjectcode，名称，org名称,term mark
create or replace function searchcourse(student_id integer,course_id integer)
	returns   setof text
as $$
	begin
	return query
	select s.code||', '||s.name||', '||se.name||', '||o.name||', '||en.mark 
	from subjects as s,orgunits as o,courses as c,semesters as se,course_enrolments as en
	where  c.id=$2 and se.id=c.semester and en.course=c.id and student=$1
	and o.id=s.offeredby and s.id=c.subject;
	end;
$$ language plpgsql;

--按照学生和机构号选出已选前五门课程
drop type if exists studentcourse cascade;
create type studentcourse as (student integer,course integer,mark integer);
create or replace function q3course(student_id integer,org_id integer)
	returns setof studentcourse
as $$
	declare	
	r studentcourse;
	count integer:=0;
	begin
	for r in 
	select student,course,mark  from course_enrolments where student= $1 and course in (
	select id from courses where subject in (select id from subjects where offeredby in (select * from allorg($2)))) order by mark desc nulls last,course asc loop 
		count:=count+1;
			if count <=5 then 
				return next r;
			end if;
	end loop;
	end;
$$ language plpgsql;
--格式化输出前五项信息
create or replace function infodisplay(student_id integer,org_id integer)
	returns text
as $$
	declare	
	out text:='';
	r integer;
	begin
	for r in
	select course from q3course($1,$2)  loop 
		out:= out || searchcourse($1,r)||E'\n';
	end loop;
	return out;
	end;
$$ language plpgsql;

--按照学生和机构号选出最低分
drop type if exists studentmark cascade;
create type studentmark as (student integer,maxmark integer);
create or replace function q3selectstu(org_id integer,min_score integer)
	returns setof studentmark
as $$
	begin
	return query
	select student,max(mark)  from course_enrolments where  course in (
	select id from courses where subject in (select id from subjects where offeredby in (select * from allorg($1)))) group by student having max(mark)>=min_score;
	end;
$$ language plpgsql;


