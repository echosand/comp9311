--COMP9311 18s1 Project 1
--
-- MyMyUNSW Solution Template


-- Q1:

Create or replace view countcourses as
Select student,count(*)
From course_enrolments
where mark >= 85
group by student
having count(*)>20;
create or replace view Q1(unswid, name)
as
select people.unswid,people.name
from people
where id in (select id from students where stype = 'intl')
and id in (select student from countcourses);




-- Q2:

--... SQL statements, possibly using other views/functions defined by you ...
Create or replace view Q2(unswid, name) as
Select rooms.unswid, rooms.longname
From rooms
Where building =(select id
From buildings
Where name='Computer Science Building')
And Capacity is not null
and Capacity >= 20
And rtype =(select id from room_types where description ='Meeting Room');


-- Q3:
--... SQL statements, possibly using other views/functions defined by you ...
create or replace view Q3(unswid, name)
as
Select People.unswid, People.name
From people
Where id in (
Select staff from course_staff where course in (
select course from course_enrolments where student = (
select id from people where name = 'Stefan Bilek')));


-- Q4:

--... SQL statements, possibly using other views/functions defined by you ...
create or replace view Q4(unswid, name)
as
Select distinct People.unswid, People.name
From people
Where id in
(select student from course_enrolments where course in
(select courses.id
from subjects,courses
where subjects.code = 'COMP3331'
and subjects.id = courses.subject))
and id not in
(select student from course_enrolments where course in
(select courses.id
from subjects,courses
where subjects.code = 'COMP3231'
and subjects.id = courses.subject));


-- Q5:

--... SQL statements, possibly using other views/functions defined by you ...
create or replace view q5a(num)
as
select count(*)
from q5a1;
create or replace view Q5a1
as
select people.name,people.unswid
from people
where id in (select id from students where stype = 'local')
and id in
(select student from program_enrolments
where semester=(select id from semesters where year
='2011' and term='S1')
and id in (select partof from stream_enrolments
where stream in (select id
from streams where name ='Chemistry')));



-- Q5:

--... SQL statements, possibly using other views/functions defined by you ...
create or replace view q5b(num)
as
select count(*) from q5b1;
create or replace view Q5b1
as
select people.unswid,people.name
from people
where id in(
select student from program_enrolments where program in(
select id from programs where offeredby in(
select id from orgunits where longname = 'School of Computer Science and Engineering'))
and
semester =(
select id from semesters where year='2011'and term='S1'))
and
id in (select id  from students where stype = 'intl');

-- Q6:
create or replace function Q6(text) returns text as
$$
select s.code||' '||s.name||' '||s.uoc
from subjects as s
where s.code = $1
$$ language sql;



-- Q7:

--... SQL statements, possibly using other views/functions defined by you ...
Create or replace view intlcount as
select s.program,count(*)
from program_enrolments as s, students as t
where s.student=t.id and t.stype='intl'
group by s.program;

create or replace view allcount as
Select program,count(*)
From program_enrolments
group by program;

create or replace view Q7(code, name)
as
select programs.code,programs.name
From programs, intlcount,allcount
Where programs .id= intlcount.program and
intlcount.program=allcount.program
and intlcount.count*1.0/allcount.count>0.5;



-- Q8:
--... SQL statements, possibly using other views/functions defined by you ...
create or replace view topmarks as
select s.subject,s.semester from courses as s,allmarks as t
where t.course=s.id and t.avg=( select max(avg) from allmarks);

create or replace view allmarks as
select s.course,avg(s.mark)
from course_enrolments as s, notnulmark as t
where t.course=s.course group by s.course;
create or replace view notnulmark as  select course, count(*)
from course_enrolments
where mark is not null group by course
having count(*)>=15;

create or replace view Q8(code,name,semester)
as
select Subjects.code, Subjects.name, semesters.name from subjects,topmarks,semesters
where subjects.id = topmarks.subject and semesters.id in(select semester from topmarks);



-- Q9:
--... SQL statements, possibly using other views/functions defined by you ...

create or replace view sn as
select distinct b.staff,d.code
from course_staff as a,staffandschool as b,courses as c,subjects as d
where a.staff=b.staff and c.id =a.course and d.id=c.subject;

create or replace view numberofsubjects as
select staff,count(*)
from sn group by staff;

Create or replace view staffandschool as
select a.staff, a.starting,b.longname
from affiliations as a,orgunits as b
where a.isprimary='t' and a.ending is null and role=(
select id from staff_roles where name = 'Head of School')
and a.orgunit=b.id and b.utype=(select id from orgunit_types where name ='School');

create or replace view Q9(name, school, email, starting, num_subjects)
as
select a.name,b.longname,a.email,b.starting,c.count
from people as a,staffandschool as b,numberofsubjects as c
where a.id = b.staff and b.staff=c.staff;


-- Q10:
create or replace view subjectselection as
select distinct subject,semester
from courses where subject in (select id from subjects where offeredby in (
select id from orgunits where longname='School of Computer Science and Engineering') and code like 'COMP93%')
and semester in (select id from semesters where year>=2003 and year<=2012 and(term = 'S1' or term ='S2'));
create or replace view subjectselect as
select subject,count(*) from subjectselection group by subject having count(*)=20;
Create or replace view coursetable as
select courses.subject,courses.id,semesters.year,semesters.term from courses,semesters
where courses.semester=semesters.id and year>=2003 and year<=2012 and (term='S1' or term='S2') and courses.subject in (select subject from subjectselect);
create or replace view allmark as
select a.course ,count(*)
from course_enrolments as a, coursetable as b
where a.course=b.id and a.mark>0
group by course;
create or replace view hdmark as
select a.course,count(*)
from course_enrolments as a, coursetable as b
where a.course=b.id and a.mark>=85
group by course;
create or replace view hdrate as
select allmark.course,coalesce((((hdmark.count*1.0)/(allmark.count*1.0))::numeric(4,2)),0.00) as hdrate
from allmark left join hdmark on hdmark.course=allmark.course;
create or replace view s1hdrate as
select a.id,b.hdrate
from coursetable as a,hdrate as b
where a.id = b.course and a.term='S1';
create or replace view s2hdrate as
select a.id,b.hdrate
from coursetable as a,hdrate as b
where a.id = b.course and a.term='S2';

create or replace view rateandyear2 as select s2hdrate.id,s2hdrate.hdrate ,semesters.year,courses.subject from courses,s2hdrate,semesters where s2hdrate.id=courses.id and semesters.id=courses.semester;
create or replace view rateandyear1 as select s1hdrate.id,s1hdrate.hdrate ,semesters.year,courses.subject from courses,s1hdrate,semesters where s1hdrate.id=courses.id and semesters.id=courses.semester;

create or replace view s1s2rate as select a.subject,concat(a.year) as year,a.hdrate as s1_HD_rate,b.hdrate as s2_HD_rate from rateandyear1 as a,rateandyear2 as b
where a.year=b.year and a.subject=b.subject;

Create or replace view Q10(code,name,year,s1_HD_rate,s2_HD_rate) as
Select b.code,b.name, right(a.year,2),a.s1_hd_rate,a.s2_hd_rate
From s1s2rate as a,subjects as b
Where b.id =a.subject;


