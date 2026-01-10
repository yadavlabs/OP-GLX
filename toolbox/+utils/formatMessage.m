function msg = formatMessage(id,msg)
%FORMATMESSAGE 
d = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
prefix = sprintf('[%s %s]', id, d);
msg = sprintf('%s %s', prefix, msg);

end

