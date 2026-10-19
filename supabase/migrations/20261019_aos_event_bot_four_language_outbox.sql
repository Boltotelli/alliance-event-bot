do $extend$
declare r record; def text; newdef text;
begin
 for r in select oid,proname from pg_proc where oid in ('public.aos_event_bot_refresh()'::regprocedure,'public.aos_event_bot_refresh_manual()'::regprocedure) loop
  def:=pg_get_functiondef(r.oid);
  if strpos(def, '(values(''de''),(''en''),(''fr''))')=0 then raise exception 'missing language anchor for %',r.proname; end if;
  newdef:=replace(def,'(values(''de''),(''en''),(''fr''))','(values(''de''),(''en''),(''fr''),(''es''))');
  execute newdef;
 end loop;
end $extend$;