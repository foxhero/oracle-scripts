select c.* from  v$process a, v$session b, v$active_session_history c where a.addr = b.paddr and a.spid=&os_processs_id order by sample_time desc