[server only]
void OnBeginPlay()
{
    log("Hello Maple World")
}


void CallPlaySoundEffect()
{
if isClient == true then
--PlaySoundEffect를 실행하라!
 
elseif isServer == true then
--클라이언트의 PlaySoundEffect를 실행하라!
end
}

