local lua = "lua5.1"
local script_name = "zero-block-hash"

-- декодирует строку из hex в бинарное представление
-- https://stackoverflow.com/a/9140231
function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

-- выводит в io.stdout заданное количество нулей
function std_write(size)
	index = index or 0;

	local buffer_size = 1024*1024*16;
	
	if ( size <= buffer_size ) then
		io.stdout:write( ('\0'):rep( size  ) );
	else
		local zero_buffer = ('\0'):rep( buffer_size );
		
		local count = math.floor( size / #zero_buffer );
		local tail = math.fmod( size, #zero_buffer );
		
		for i = 1, count do
			io.stdout:write( zero_buffer );
		end
		
		if ( tail > 0 ) then
			io.stdout:write( zero_buffer:sub( 1, tail ) );
		end
	end
end

--ED2K zero block
local md4_cmd = lua..' -l"'..script_name..'" -e"std_write(9728000);"|rhash -p"%x{md4}" -';

function gen_md4_hash()
	-- запускаем функцию std_write которая передаёт в RHash необходимое количество нулевых байт.
	local md4 = io.popen(md4_cmd, "rb");
	
	-- получаем результат вычислений
	local hash = md4:read("*a"):upper(); 
	
	-- выводим результат
	print("")
	print("// md4_hash")
	print("// Hash: "..hash, "Size: 9728000");
	md4:close();
end

--Bittorrent zero block
local sha1_cmd = lua..' -l"'..script_name..'" -e"std_write(%s);"|rhash -p"%%x{sha1}" -';

function gen_sha1_hashes(hash_count)
	local size = 16384 -- минимальный размер блока
	local sha1 = {};
	hash_count = hash_count or 13; -- по умолчанию считаем 13 хешей
	
	-- параллельные вычисления
	-- запускаем счёт хешей передавая размер блока в std_write
	for i = 1, hash_count do
		sha1[i] = io.popen(sha1_cmd:format(size), "rb");
		size = size * 2;
	end
	
	size = 16384
	-- получаем результаты
	print("")
	print("// sha1_hashes")
	for i = 1, #sha1 do
		local hash = sha1[i]:read("*a"):upper();
		sha1[i]:close();
		print( "// Hash: " .. hash .. "\tSize: " .. size );
		size = size * 2;
	end
end

--Tiger Tree Hash Leaf block
local leaf_hash_cmd = lua..' -l"'..script_name..'" -e"std_write_leaf_hash()"';

--Tiger Tree Hash Internal block
local internal_hash_cmd = lua..' -l"'..script_name..'" -e"std_write_internal_hash(\'%s\')"';

-- передаёт в rhash нуль блок с префиксом '\0'  
function std_write_leaf_hash()
	local tiger = io.popen('rhash -p"%x{tiger}" -', "wb") 
	tiger:write('\0'..('\0'):rep(1024))
	tiger:close()
end

-- передаёт в rhash пару одинаковых хешей с префиксом '\1'
function std_write_internal_hash(hash)
	local tiger = io.popen('rhash -p"%x{tiger}" -', "wb");
	hash = hash:fromhex();
	tiger:write('\1'..hash..hash)
	tiger:close()
end

-- хеш от нуль блока
function tth_leaf()
	local rhash = io.popen(leaf_hash_cmd, "rb");
	local hash = rhash:read("*a");
	rhash:close();
	return hash;
end

-- хеш от пары одинаковых хешей
function tth_root(hash_hex)
	local rhash = io.popen(internal_hash_cmd:format(hash_hex), "rb");
	local hash = rhash:read("*a");
	rhash:close();
	return hash;
end

-- вычисляем заданное количество хешей
function gen_tth_hashes(hash_count)
	-- получаем хеш от нуль блока
	local hash_hex = tth_leaf():upper();
	hash_count = hash_count or 37;
	hash_count = hash_count - 1;
	print("")
	print("// tth_hashes")
	for i = 0, hash_count do
		print("// Hash: "..hash_hex, " Size: "..(1024*2^i));
		 -- получаем хеш от нуль блока вдвое большего размера
		hash_hex = tth_root(hash_hex):upper();
	end
end