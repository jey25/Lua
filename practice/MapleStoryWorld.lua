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


[ServerOnly]
void CallPlaySoundEffect()
{
self:PlaySoundEffect()  -- 어떤 공간에서든 같은 공간의 함수를 호출하듯이 사용할 수 있다.
}
[client] --각 함수별로 어떤 공간에서 호출하고 실행할지를 설정할 수 있다.
void PlaySoundEffect()
{
--코드 작성 공간입니다.
}