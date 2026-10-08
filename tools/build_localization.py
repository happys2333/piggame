#!/usr/bin/env python3
"""Build the three-language Godot CSV from reviewable Chinese/English copy."""

from __future__ import annotations

import csv
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "game" / "data"
sys.path.insert(0, os.environ.get("PIGGAME_OPENCC_PATH", str(Path.home() / "Library/Caches/piggame/python")))
try:
    from opencc import OpenCC
except ImportError as exc:  # pragma: no cover - generation-time dependency
    raise SystemExit("Install opencc-python-reimplemented before rebuilding localization") from exc

convert = OpenCC("s2twp").convert
rows: dict[str, tuple[str, str, str]] = {}


def add(key: str, zh: str, en: str, tw: str | None = None) -> None:
    if key in rows:
        raise ValueError(f"duplicate localization key: {key}")
    rows[key] = (zh, tw or convert(zh), en)


UI = {
    "PERFORMANCE_TITLE": ("猪猪表情与动作剧场", "Pig Faces and Little Performances"),
    "PERFORMANCE_INTRO": ("同一只猪猪，五类可组合表现。性格、住客与收益都不变。", "One pig, five combinable categories. Residents, personality, and rewards stay unchanged."),
    "PERFORMANCE_CATEGORY": ("表现分类", "Performance Category"),
    "PERFORMANCE_FACES": ("表情与五官", "Faces"),
    "PERFORMANCE_POSES": ("四帧小动作", "Animated Poses"),
    "PERFORMANCE_OUTFIT_ACTIONS": ("装扮专属动作", "Outfit Combinations"),
    "PERFORMANCE_STATES": ("临时梗状态", "Meme States"),
    "PERFORMANCE_FORMS": ("特殊形态", "Special Forms"),
    "PERFORMANCE_STOP": ("回到普通猪猪", "Back to Ordinary Piggy"),
    "PERFORMANCE_TEMPORARY": ("表情展示两分钟，动作八秒，梗状态与形态随后自动恢复；不写入存档、不要求照顾，不补演后台错过的动作。摸摸或戳戳也会结束展示。", "Faces last two minutes, poses eight seconds; states and forms return to normal automatically. No saves, care requirements, or background catch-up. A pat or poke also ends the performance."),
    "PERFORMANCE_OUTFIT_ACTION": ("展示这套装扮的小动作", "Show This Outfit's Little Action"),
    "PERFORMANCE_OUTFIT_COMBO": ("{outfit} · {pose}", "{outfit} · {pose}"),
    "PERFORMANCE_WEAR_FIRST": ("先穿上这套装扮；组合动作不需要额外付费。", "Wear this outfit first. No extra purchase is needed for its combination."),
    "FACE_DOT": ("豆豆眼", "Beady Eyes"),
    "FACE_SQUINT": ("眯眼", "Happy Squint"),
    "FACE_DEADPAN": ("死鱼眼", "Deadpan Eyes"),
    "FACE_TEARS": ("泪流满面", "Streaming Tears"),
    "FACE_QUAKE": ("瞳孔地震", "Pupil Panic"),
    "FACE_SLY": ("阴险笑 · 只是想偷饼干", "Mischievous Cookie Smile"),
    "FACE_GLARE": ("无语凝视", "Speechless Stare"),
    "FACE_SLEEPY": ("睡眼惺忪", "Sleepy Eyelids"),
    "FACE_SHOCK": ("张嘴震惊", "Open-Mouthed Surprise"),
    "POSE_PRONE": ("趴着伸蹄", "Prone Stretch"),
    "POSE_FLAT": ("躺平摊成猪饼", "Pancake Flop"),
    "POSE_HEAD_HOLD": ("抱头想猪意", "Hooves on Head"),
    "POSE_KNEEL": ("跪下鞠个猪躬", "Little Kneeling Bow"),
    "POSE_CORNER": ("蹲墙角搓蹄", "Corner Crouch"),
    "POSE_ARMS": ("张开双手求贴贴", "Open-Hoof Hug"),
    "POSE_UPSIDE": ("四脚朝天扑腾", "Belly-Up Wiggle"),
    "POSE_PEEK": ("偷偷探头", "Shy Peek"),
    "POSE_CRAWL": ("扭曲爬行 · 可爱版", "Silly Wriggling Crawl"),
    "MEME_SILLY": ("笨蛋猪 · 猪脑过载", "Silly Pig · Brain Buffering"),
    "MEME_SILLY_LINE": ("{name}：猪意很多，但猪脑一次只能处理一个。", "{name}: So many pig ideas, one tiny processor."),
    "MEME_WORKER": ("打工猪", "Office Pig"),
    "MEME_WORKER_LINE": ("{name}：正在努力工作，争取早日实现饼干自由。", "{name}: Working towards financial cookie independence."),
    "MEME_SLACK": ("摆烂猪", "Slacker Pig"),
    "MEME_SLACK_LINE": ("{name}：今天的猪要任务，是把地板躺得更舒服。", "{name}: Today's pig priority: improve floor comfort."),
    "MEME_RAGE": ("暴怒猪 · 无声哼哼", "Furious Pig · Silent Grumble"),
    "MEME_RAGE_LINE": ("{name}：气成河豚……等等，猪猪不是河豚。", "{name}: Puffing up with rage… wait, pigs aren't pufferfish."),
    "MEME_WRONGED": ("委屈猪", "Wronged Pig"),
    "MEME_WRONGED_LINE": ("{name}：最后一块饼干没有猪的名字，但猪觉得有。", "{name}: That last cookie had no name on it. I assumed mine."),
    "MEME_RULER": ("世界主宰猪", "Pig Ruler of the World"),
    "MEME_RULER_LINE": ("{name}：本猪宣布，今天所有人都可以好好休息。", "{name}: By pig decree, everyone may take a proper rest."),
    "FORM_WORKER": ("小衬衫打工形态", "Tiny Office-Worker Form"),
    "FORM_RULER": ("纸冠主宰形态", "Paper-Crown Ruler Form"),
    "PERSONALITY_SELECTOR": ("猪猪性格", "Pig Personality"),
    "PERSONALITY_SETUP_INTRO": ("性格可以自己选，也可以随机遇见。只影响互动表情和说话方式，点数、熟悉度、需求消耗与照顾频率都一样；选定后不会因改名、离开或重启改变。", "Choose a personality or meet one at random. It changes reaction expressions and wording, not points, familiarity, needs, or care frequency. Naming, absence, and restarting never change it."),
    "PERSONALITY_RANDOM": ("随机遇见 · 五种性格等概率", "Random · Equal Chance of Five Personalities"),
    "PERSONALITY_RANDOM_DESCRIPTION": ("迎接时才随机决定，每只猪猪独立生成；没有稀有度或强弱之分。", "Rolled independently when welcomed. No rarity tiers or stronger personalities."),
    "PERSONALITY_UNASSIGNED": ("自然随性 · 尚未选择", "Easygoing · Not Chosen Yet"),
    "PERSONALITY_CARD": ("性格：{personality}", "Personality: {personality}"),
    "PERSONALITY_LEGACY_INTRO": ("这只猪猪来自尚未设置性格的存档，可以补选一次；不选也能保持原来的生活。", "This pig has no saved personality yet. Choose once if you like, or keep its original easygoing reactions."),
    "PERSONALITY_INITIAL_CONFIRM": ("为这只猪猪确定性格", "Choose This Pig's Personality"),
    "PERSONALITY_LIVELY_NAME": ("活泼", "Lively"),
    "PERSONALITY_LIVELY_DESCRIPTION": ("摸摸头就开心地贴过来，被戳一下也会认真地嘀咕两句。", "Leans happily into head pats and has a little grumble after a poke."),
    "PERSONALITY_TSUNDERE_NAME": ("傲娇", "Tsundere"),
    "PERSONALITY_TSUNDERE_DESCRIPTION": ("嘴上说才没有很开心，表情却藏不住；被戳时会假装很有威严。", "Claims not to enjoy the attention, but its face gives it away. Pretends to be stern when poked."),
    "PERSONALITY_TSUNDERE_PET": ("{name}：才、才不是在等你摸头……再摸一下也不是不可以。", "{name}: I wasn't waiting for a head pat… though one more wouldn't hurt."),
    "PERSONALITY_TSUNDERE_POKE": ("{name}：哼，这可是猪要保护的肚子！", "{name}: Hmph! This belly is under pig protection!"),
    "PERSONALITY_LAZY_NAME": ("懒惰", "Lazy"),
    "PERSONALITY_LAZY_DESCRIPTION": ("喜欢慢慢来，摸头时打个哈欠，被戳也只想换个舒服的姿势。", "Takes life slowly, yawns through head pats, and answers a poke with another sleepy blink."),
    "PERSONALITY_LAZY_PET": ("{name}：这叫猪动休息……你的手先别走。", "{name}: This is proactive pig rest… leave your hand there a little longer."),
    "PERSONALITY_LAZY_POKE": ("{name}：收到，等我把这半个哈欠打完。", "{name}: Noted. Let me finish this half-yawn first."),
    "PERSONALITY_SHY_NAME": ("社恐", "Shy"),
    "PERSONALITY_SHY_DESCRIPTION": ("安静地享受摸头，突然被戳会睁圆眼睛；不需要更多陪伴，也不会因离开难过。", "Quietly enjoys head pats and widens its eyes at a surprise poke. Needs no extra company and never resents your absence."),
    "PERSONALITY_SHY_PET": ("{name}：小声说，和你待着还挺舒服的。", "{name}: Quietly… it's quite comfy here with you."),
    "PERSONALITY_SHY_POKE": ("{name}：啊！原来是你，那我就放心一点点。", "{name}: Oh! It's you. That's a little reassuring."),
    "PERSONALITY_FOODIE_NAME": ("贪吃", "Foodie"),
    "PERSONALITY_FOODIE_DESCRIPTION": ("摸头也能联想到零食，被戳肚子会想起饼干；不会消耗更多食物或催你投喂。", "Even a head pat brings snacks to mind; a belly poke reminds it of cookies. Never consumes extra food or nags for feeding."),
    "PERSONALITY_FOODIE_PET": ("{name}：摸头真好。要是手里刚好有饼干，那就猪事顺利了。", "{name}: Head pats are lovely. A cookie in that hand would make it a snoutstanding day."),
    "PERSONALITY_FOODIE_POKE": ("{name}：这里装着饼干的回忆，不是催你投喂哦。", "{name}: Cookie memories live in here. That's not a request for more food."),
    "DESKTOP_COMPANION_SETTINGS": ("陪伴与防打扰", "Companion & Interruption Protection"),
    "DESKTOP_BACKGROUND_SHIELD": ("切换到其他游戏或应用后，猪咪自动收起主动提示、停止漫步和帧动画，并撤销置顶；养成仍继续。只有主动点击、触控或操作菜单才会得到反馈，鼠标经过不算互动。回来后不会补发过期提醒。", "When you switch to another game or app, your pig hides proactive messages, stops roaming and frame animation, and drops always-on-top. Progress continues. Only deliberate clicks, touch, or menu actions get feedback; hovering does not count. Missed reminders are never replayed."),
    "DESKTOP_QUIET": ("安静模式 · 不主动动作或提示", "Quiet Mode · No Proactive Motion or Messages"),
    "DESKTOP_DO_NOT_DISTURB": ("勿扰模式 · 同时撤销置顶", "Do Not Disturb · Also Disable Always-on-Top"),
    "DESKTOP_BEHAVIOR_FREQUENCY": ("主动行为频率 · 仅在本应用前台生效；安静、勿扰和暂停设置优先。", "Proactive behavior frequency · Foreground only; quiet, do not disturb, and pause take priority."),
    "DESKTOP_FREQUENCY_FREQUENT": ("自然切换", "Natural Transitions"),
    "DESKTOP_FREQUENCY_NORMAL": ("适中 · 至少间隔 45 秒", "Normal · At Least 45 Seconds Apart"),
    "DESKTOP_FREQUENCY_RARE": ("偶尔 · 至少间隔 2 分钟", "Occasional · At Least 2 Minutes Apart"),
    "DESKTOP_FREQUENCY_OFF": ("关闭主动行为与提示", "No Proactive Behavior or Messages"),
    "DESKTOP_PRIVACY_BOUNDARY": ("防打扰只判断本游戏窗口的焦点，不扫描进程、读取其他窗口、追踪全局鼠标、录制系统音乐或抓取桌面。计时只保留在内存中，退出即结束，不记录工作历史。安静、勿扰和频率仅保存在这台机器上。", "Protection only checks this game's window focus. It does not scan processes, read other windows, track the global cursor, record system music, or capture your desktop. The timer is memory-only, ends on exit, and keeps no work history. Quiet, do not disturb, and frequency settings stay on this machine."),
    "FOCUS_TIMER_INTRO": ("25 分钟专注，猪咪陪你读书；主动开始 5 分钟休息后一起拉伸。到点不弹窗、不发声、不抢焦点；后台、安静或勿扰时不提示。睡眠/唤醒的长停顿不计入专注时间，没有奖励、考核或打卡。", "Focus for 25 minutes while your pig reads; start a 5-minute break yourself to stretch together. No pop-up, sound, or focus stealing. No reminders in the background, quiet, or do not disturb modes. Long sleep/wake gaps do not count as focus time. No rewards, scores, or check-ins."),
    "FOCUS_TIMER_START": ("开始 25 分钟专注", "Start 25-Minute Focus"),
    "FOCUS_TIMER_PAUSE": ("暂停计时", "Pause Timer"),
    "FOCUS_TIMER_RESUME": ("继续计时", "Resume Timer"),
    "FOCUS_TIMER_REST": ("开始 5 分钟休息", "Start 5-Minute Break"),
    "FOCUS_TIMER_STOP": ("结束本次计时", "End This Timer"),
    "FOCUS_TIMER_STATUS": ("{phase} · {time} {paused}", "{phase} · {time} {paused}"),
    "FOCUS_PHASE_IDLE": ("随便待着", "Just Hanging Out"),
    "FOCUS_PHASE_WORK": ("专注读书中", "Reading Together"),
    "FOCUS_PHASE_REST_READY": ("可随时开始休息", "Break Available Whenever You Like"),
    "FOCUS_PHASE_REST": ("一起拉伸中", "Stretching Together"),
    "FOCUS_PHASE_FINISHED": ("本次休息结束", "Break Finished"),
    "FOCUS_PAUSED": ("（已暂停）", "(Paused)"),
    "FOCUS_BREAK_READY": ("猪咪合上书：要不要喝点水、伸个懒腰？休息随时可以开始。", "Your pig closes its book: some water and a stretch? Start your break whenever you like."),
    "DESKTOP_COMPATIBILITY_FALLBACK": ("当前环境采用普通小窗 · 保留控制条与系统标题栏", "Normal Window in This Environment · Controls and System Title Bar Kept"),
    "RESIDENTS_TITLE": ("猪猪住客 · 起名与陪伴", "Pig Residents · Names and Company"),
    "RESIDENTS_INTRO": ("最多一起养四只猪猪，各自有名字、熟悉度、小屋布置、相册和小计划。切换当前陪伴时，其他猪猪也会按离线规则慢慢生活；没有离开惩罚，点数不互相转移。桌面只显示当前这一只。", "Raise up to four pigs, each with its own name, familiarity, room, album, and little plans. Other residents live at the offline rate while you switch company. No absence penalties or point transfers. Desktop mode shows only the current pig."),
    "RESIDENTS_CARD": ("住客 {number} · {name} · 熟悉度 {level} · 手账 {notes} 段", "Resident {number} · {name} · Familiarity {level} · {notes} notes"),
    "RESIDENTS_CURRENT": ("正在陪伴", "Current Companion"),
    "RESIDENTS_SWITCH": ("陪这只猪猪", "Spend Time with This Pig"),
    "RESIDENTS_RENAME": ("给「{name}」改个名字，原有进度全部保留。", "Rename “{name}” without changing any progress."),
    "RESIDENTS_RENAME_INPUT": ("当前猪猪的新名字", "A New Name for the Current Pig"),
    "RESIDENTS_RENAME_CONFIRM": ("保存新名字", "Save New Name"),
    "RESIDENTS_CAPACITY": ("已入住 {count}/{maximum} 只 · 新住客从自己的第一天开始，原来的猪猪不会被替换。", "{count}/{maximum} residents · Newcomers start their own first day; existing pigs are never replaced."),
    "RESIDENTS_ADD_INPUT": ("新住客叫什么？最多 16 个字。", "Name the new resident (up to 16 characters)."),
    "RESIDENTS_ADD": ("迎接新住客", "Welcome a New Resident"),
    "ALBUM_LIFE_PLANS": ("小计划", "Little Plans"),
    "DESKTOP_PIG_ONLY": ("只显示猪咪 · 右键打开菜单，Esc 恢复控制条", "Pig Only · Right-click for Menu, Esc for Controls"),
    "DESKTOP_RESUME": ("继续动画", "Resume Animation"),
    "LIFE_PLAN_INTRO": ("选一本慢慢做的小计划。猪咪在线、桌面陪伴或离线时都会积累灵感；可随时换本、暂停和继续，进度与手账不会清空。没有期限，也不需要打卡。手账只作纪念，不增加点数或熟悉度。", "Choose a little project to take slowly. Inspiration grows in the room, on your desktop, or offline. Switch, pause, or resume any time without losing progress or notes. No deadlines or check-ins. Notes are keepsakes, not points or familiarity rewards."),
    "LIFE_PLAN_COLLECTION": ("已经留下 {count}/{total} 段手账", "{count}/{total} notes kept"),
    "LIFE_PLAN_PAUSE": ("先随便待着 · 保留所有进度", "Just Hang Out · Keep All Progress"),
    "LIFE_PLAN_CHOOSE": ("开始慢慢做", "Take It Slowly"),
    "LIFE_PLAN_CONTINUE": ("接着慢慢做", "Carry On Slowly"),
    "LIFE_PLAN_ACTIVE": ("猪咪正在慢慢做", "Your Pig Is Taking Its Time"),
    "LIFE_PLAN_COMPLETE": ("三段手账都留下了", "All Three Notes Kept"),
    "LIFE_PLAN_PROGRESS": ("手账 {done}/{total} · 灵感 {percent}%", "Notes {done}/{total} · Inspiration {percent}%"),
    "LIFE_PLAN_FURNITURE": ("摆进房间更容易有灵感：{items}", "Room inspiration: {items}"),
    "LIFE_PLAN_RATE": ("房间灵感速度 {rate}% · 对应家具每件 +20%，最多两件；相关行为完成后另添 10 秒灵感。", "Room inspiration rate {rate}%. Matching furniture adds 20% each, up to two pieces; a completed matching behavior adds 10 seconds."),
    "LIFE_PLAN_ENTRY_WRITTEN": ("{title}：{note}", "{title}: {note}"),
    "LIFE_PLAN_ENTRY_WAITING": ("{title} · 累计 {minutes} 分钟灵感后写下，不限时间。", "{title} · Written after {minutes} minutes of inspiration, whenever that happens."),
    "LIFE_PLAN_OFFLINE": ("猪咪还给小计划添了 {count} 段手账，可以到相册的小计划页看看。", "Your pig also added {count} project notes. Find them under Little Plans in the album."),
    "UI_ALBUM": ("相册", "Album"),
    "UI_SCREENSHOT": ("拍照", "Photo"),
    "UI_SETTINGS": ("设置", "Settings"),
    "UI_FURNITURE": ("家具", "Furniture"),
    "UI_SNACKS": ("零食", "Snacks"),
    "UI_OUTFITS": ("装扮", "Outfits"),
    "UI_TENDENCY": ("今日倾向", "Today's Mood"),
    "UI_TENDENCY_LOCKED": ("熟悉度 5 级解锁今日倾向。", "Today's Mood unlocks at Familiarity 5."),
    "UI_DESKTOP": ("桌面陪伴", "Desktop Pal"),
    "UI_DESKTOP_HINT": ("让猪咪留在桌面边缘陪你。", "Let your pig stay by the edge of the desktop."),
    "UI_DESKTOP_LOCKED": ("熟悉度 2 级解锁。", "Unlocks at Familiarity 2."),
    "UI_POINTS": ("日常点数  {points}", "Daily Points  {points}"),
    "UI_PIG_NAME_LEVEL": ("{name} · 熟悉度 {level}", "{name} · Familiarity {level}"),
    "UI_CLOSE": ("关闭", "Close"),
    "UI_CONFIRM": ("就叫这个", "Use This Name"),
    "UI_BUY": ("购买 · {price} 点", "Buy · {price} pts"),
    "UI_PLACE": ("放进房间", "Place in Room"),
    "UI_FEED": ("投喂 · {price} 点", "Feed · {price} pts"),
    "UI_EQUIP": ("穿上", "Equip"),
    "UI_EQUIPPED": ("正在穿", "Equipped"),
    "UI_REMOVE_OUTFIT": ("摘下装扮", "Remove Outfit"),
    "UI_UNLOCK_LEVEL": ("熟悉度 {level} 级解锁", "Unlocks at Familiarity {level}"),
    "UI_SELECTED": ("已选择", "Selected"),
    "UI_CHOOSE": ("选择", "Choose"),
    "ROOM_PALETTE_TITLE": ("小屋整体配色", "Room Color Palette"),
    "ROOM_PALETTE_ROSE": ("莓果暖粉", "Warm Berry"),
    "ROOM_PALETTE_MINT": ("薄荷午后", "Mint Afternoon"),
    "ROOM_PALETTE_NIGHT": ("安静夜色", "Quiet Night"),
    "ROOM_PALETTE_MINT_LOCKED": ("熟悉度 7 级解锁。", "Unlocks at Familiarity 7."),
    "ROOM_PALETTE_NIGHT_LOCKED": ("收集 36 个表情后解锁。", "Unlocks after collecting 36 expressions."),
    "FURNITURE_CHOOSE_SLOT": ("选择固定插槽", "Choose a Fixed Slot"),
    "FURNITURE_CHOOSE_SLOT_DESC": ("要把「{item}」放在哪里？占用中的插槽会明确替换原家具。", "Where should “{item}” go? Choosing an occupied slot clearly replaces its current furniture."),
    "FURNITURE_SLOT_LABEL": ("{area} · 插槽 {number}（现在：{current}）", "{area} · Slot {number} (now: {current})"),
    "FURNITURE_SLOT_EMPTY": ("空着", "Empty"),
    "FURNITURE_CURRENT_SLOT": ("现在位于：{area} · 插槽 {number}", "Currently in: {area} · Slot {number}"),
    "FURNITURE_INVITE": ("邀请猪咪试一试", "Invite Your Pig to Try It"),
    "FURNITURE_DECORATION_ONLY": ("这件家具只负责让房间更像家。", "This piece simply makes the room feel more like home."),
    "FURNITURE_ATMOSPHERE_ONLY": ("这件家具会轻轻改变房间的气氛。", "This piece gently changes the room atmosphere."),
    "FURNITURE_REACT": ("看看猪咪怎么说", "See What Your Pig Thinks"),
    "FURN_FRUIT_BOWL_REACTION": ("{name} 绕着水果碗看了一圈，认为看过就算补充维生素。", "{name} circles the fruit bowl once and decides looking counts as vitamins."),
    "FURN_ROBOT_DOCK_REACTION": ("{name} 认真检查了空底座，宣布骑士正在巡逻。", "{name} inspects the empty dock and announces that its rider is on patrol."),
    "FURN_TEA_TRAY_REACTION": ("{name} 坐在茶盘旁边，宣布今天已经被热气改善了。", "{name} sits by the tea tray and says the steam has already improved the day."),
    "FURNITURE_REPLACE": ("打开家具清单替换", "Open Furniture List to Replace"),
    "CATALOG_FURNITURE_INTRO": ("家具使用固定插槽。功能家具会把新动作和小剧场加入猪咪的生活。", "Furniture uses fixed slots. Functional pieces add new actions and memories to your pig's life."),
    "CATALOG_SNACKS_INTRO": ("零食每次消耗日常点数。连续投喂仍有表情反馈，但当天只有第一次会额外产出点数。", "Each snack costs Daily Points. Repeated feeding still gets a reaction, but only the first feed of the day grants extra points."),
    "CATALOG_OUTFITS_INTRO": ("装扮只改变外观，不提供数值优势。买下后可以随时更换。", "Outfits are cosmetic only. Once bought, they can be changed at any time."),
    "TENDENCY_INTRO": ("倾向不是任务，也没有选错惩罚。它只会轻轻改变今天更容易出现的行为。", "This is not a task and there is no wrong choice. It only gently shifts which behaviors are more likely today."),
    "TENDENCY_REST_NAME": ("慢慢休息", "Take It Slow"),
    "TENDENCY_REST_DESC": ("更偏向睡觉、窗边和安静事件。", "Favors sleep, window time, and quiet events."),
    "TENDENCY_FOOD_NAME": ("吃点好的", "Eat Something Nice"),
    "TENDENCY_FOOD_DESC": ("更偏向厨房、零食和料理事件。", "Favors kitchen, snack, and cooking events."),
    "TENDENCY_ACTIVE_NAME": ("稍微运动", "Move a Little"),
    "TENDENCY_ACTIVE_DESC": ("更偏向跑步、瑜伽和活动事件。", "Favors running, yoga, and active events."),
    "TENDENCY_EXPLORE_NAME": ("随便看看", "See What Happens"),
    "TENDENCY_EXPLORE_DESC": ("分配较平均，并提高未见内容的机会。", "Keeps things balanced and favors unseen content."),
    "ALBUM_EXPRESSIONS": ("表情册", "Expressions"),
    "ALBUM_UNKNOWN_EXPRESSION": ("还没见过的表情", "An Expression Not Yet Seen"),
    "ALBUM_DATE_UNKNOWN": ("旧存档未记录", "Not Recorded in This Older Save"),
    "ALBUM_MEMORIES": ("生活照片", "Memories"),
    "ALBUM_DIARY": ("章节日记", "Chapter Diary"),
    "ALBUM_EXPRESSION_DATE": ("第一次出现：{date}", "First seen: {date}"),
    "ALBUM_UNKNOWN_MEMORY": ("一段还没发生的日常", "A daily moment yet to happen"),
    "ALBUM_MEMORY_HINT": ("满足条件后会进入待看队列，不会永久错过。", "Once its conditions are met, it enters the watch-later queue and is never permanently missed."),
    "ALBUM_WATCH": ("观看", "Watch"),
    "ALBUM_REPLAY": ("重看", "Replay"),
    "ALBUM_EXPORT": ("导出照片", "Export Photo"),
    "ALBUM_VIEW_PHOTO": ("隐藏界面查看", "View Without UI"),
    "PHOTO_FRAME_TITLE": ("相册相框", "Album Photo Frame"),
    "PHOTO_FRAME_PLAIN": ("轻轻留白", "Soft Margin"),
    "PHOTO_FRAME_BERRY": ("莓果纪念", "Berry Keepsake"),
    "PHOTO_FRAME_STAR": ("星星全收集", "Star Collector"),
    "PHOTO_FRAME_BERRY_LOCKED": ("收集 16 个表情后解锁。", "Unlocks after collecting 16 expressions."),
    "PHOTO_FRAME_STAR_LOCKED": ("收集全部 48 个表情后解锁。", "Unlocks after collecting all 48 expressions."),
    "ALBUM_PHOTO_DATE": ("拍摄日期：{date}", "Captured: {date}"),
    "ALBUM_ASSOCIATED_EVENT": ("关联：{event}", "Related: {event}"),
    "ALBUM_DESKTOP_FAVORITE": ("桌面待机偏好", "Desktop Idle Favorite"),
    "ALBUM_HIDDEN_HINT": ("熟悉度 9 级后，猪咪也许愿意透露这条隐藏线索。", "At Familiarity 9, your pig may reveal this hidden hint."),
    "EVENT_SKIP": ("先记进相册", "Save to Album"),
    "AREA_SLEEP": ("睡眠角", "Sleep Nook"),
    "AREA_SNACK": ("零食角", "Snack Nook"),
    "AREA_ACTIVITY": ("活动角", "Activity Nook"),
    "AREA_WINDOW": ("窗边角", "Window Nook"),
    "STATUS_SLEEPY": ("困困的，眼皮正在开会", "Sleepy—its eyelids are in a meeting"),
    "STATUS_HUNGRY": ("有点馋，但正在讲道理", "A little peckish, but being reasonable"),
    "STATUS_BORED": ("认真地发着呆", "Taking daydreaming very seriously"),
    "STATUS_ENERGETIC": ("精神得很，可能要做点什么", "Wide awake and possibly about to do something"),
    "STATUS_CONTENT": ("今天也过得很充实", "Having another very full day"),
    "NAME_PROMPT_TITLE": ("新住客", "A New Roommate"),
    "NAME_PROMPT_TEXT": ("它看起来已经决定住下了。要怎么称呼它？", "It looks like it has already decided to stay. What should you call it?"),
    "NAME_PROMPT_PLACEHOLDER": ("输入名字（最多 16 个字）", "Enter a name (up to 16 characters)"),
    "NAME_DEFAULT": ("猪咪", "Piggy"),
    "TUTORIAL_NAME": ("先给新住客取个名字。", "Start by naming your new roommate."),
    "TUTORIAL_PET": ("点身体是摸摸，点鼻子是戳戳，看看它会摆出什么表情。", "Click the body to pet or the snout to poke, and watch the face your pig makes."),
    "TUTORIAL_FEED": ("打开零食，第一次投喂会把首个表情收进相册。", "Open Snacks. Your first feed adds the first expression to the album."),
    "TUTORIAL_FURNITURE": ("买一件家具，新的生活方式会跟着出现。", "Buy a piece of furniture and a new way of living appears with it."),
    "TUTORIAL_ALBUM": ("相册会保存表情和所有待看的小剧场。", "The album keeps expressions and every memory waiting to be watched."),
    "TUTORIAL_DESKTOP": ("熟悉度 2 级后，试试桌面陪伴；随时可以回到小屋。", "At Familiarity 2, try Desktop Pal. You can return to the room at any time."),
    "TUTORIAL_TENDENCY": ("熟悉度 5 级会开放今日倾向；选择一次，给随机日常一点柔和方向。", "Today's Mood opens at Familiarity 5. Choose once to gently steer random daily life."),
    "OFFLINE_TITLE": ("猪咪刚才的日子", "While You Were Away"),
    "OFFLINE_NONE": ("猪咪只是眨了眨眼。", "Your pig barely had time to blink."),
    "OFFLINE_SHORT": ("你离开了约 {hours} 小时。猪咪自己过得不错，带回了 {points} 点日常点数。", "You were away for about {hours} hours. Your pig did fine and brought back {points} Daily Points."),
    "OFFLINE_LONG": ("猪咪认真生活了约 {hours} 小时，前 8 小时完整结算，之后按低速记录，共获得 {points} 点。", "Your pig lived very seriously for about {hours} hours. The first 8 hours were full-rate, then low-rate, for {points} points total."),
    "OFFLINE_MANY_DAYS": ("猪咪过了几天自己的日子。收益已按 24 小时上限结算，共 {points} 点，没有任何内容被错过。", "Your pig lived a few days of its own. Rewards were capped at 24 hours for {points} points, and no content was missed."),
    "OFFLINE_MEMORIES": ("还有 {count} 段回忆在相册里等你。", "There are {count} memories waiting in the album."),
    "DIARY_CHAPTER_1": ("搬进来：我们没有商量，它已经把床当成自己的了。", "Moving In: We did not discuss it. The bed is already theirs."),
    "DIARY_CHAPTER_2": ("找到节奏：吃饭、睡觉、发呆，每一件都做得很有原则。", "Finding a Rhythm: Eating, sleeping, and staring into space—each done with principles."),
    "DIARY_CHAPTER_3": ("兴趣很多：它愿意尝试，只是不保证坚持。", "Many Interests: It will try anything, with no promise to continue."),
    "DIARY_CHAPTER_4": ("窗边的日子：天气经过窗外，我们慢慢熟悉彼此。", "Days by the Window: Weather passes outside as we slowly get to know each other."),
    "DIARY_CHAPTER_5": ("普通的一天：什么大事也没发生，但这一天已经很好。", "An Ordinary Day: Nothing big happened, and the day was already enough."),
    "DIARY_LOCKED": ("熟悉度 {level} 级后再写这一页。", "This page will be written at Familiarity {level}."),
    "ENDING_READY": ("24 段核心日常已经装满相册，主题结局正在等你。", "All 24 core daily moments fill the album. The thematic ending is waiting."),
    "ENDING_FREE_COMPANION": ("结局之后没有结束：现在是自由陪伴模式，所有养成、收集和桌面陪伴都会继续。", "The ending was not the end. Free Companion Mode continues every collection, room, and desktop activity."),
    "ENDING_REPLAY": ("重看感谢照片与制作名单", "Replay Thanks & Credits"),
    "ENDING_TITLE": ("普通的一天", "An Ordinary Day"),
    "ENDING_THANKS": ("{name}：谢谢你陪我什么也没做。\n今天完成了一件大事：一起过完今天。", "{name}: Thank you for doing nothing with me.\nWe finished one big thing today: getting through today together."),
    "ENDING_CREDITS": ("《猪咪今天也没干嘛》\n设计、程序与文字：本项目团队\n当前视觉：image_gen（用户委托生成）\n音频：开发占位，全程静音\n归档上游猪图形母版：Google Noto Emoji（Apache 2.0，固定历史提交）\n感谢每一个愿意把普通日子慢慢过完的人。", "Piggy Did Nothing Today\nDesign, code, and writing: the project team\nCurrent visuals: image_gen, commissioned by the user\nAudio: silent development placeholders\nArchived upstream pig graphic master: Google Noto Emoji (Apache 2.0, pinned historical commit)\nThank you to everyone willing to live an ordinary day slowly."),
    "ENDING_CONTINUE": ("继续自由陪伴", "Continue in Free Companion Mode"),
    "DEMO_COMPLETE_TITLE": ("试玩日常已经装满", "The Demo Days Are Full"),
    "DEMO_COMPLETE_BODY": ("你已经看完试玩版的 4 段小剧场。猪咪仍可继续生活、布置和待在桌面；试玩存档采用正式版结构，可在正式版中继续。", "You have seen all four demo memories. Your pig can keep living, decorating, and staying on the desktop; this save uses the full game's structure and can continue there."),
    "DEMO_COMPLETE_SILHOUETTES": ("正式版范围：32 件家具 · 48 个表情 · 24 段小剧场 · 12 套装扮", "Full-game scope: 32 furniture · 48 expressions · 24 memories · 12 outfits"),
    "DEMO_CONTINUE": ("继续试玩陪伴", "Keep Playing the Demo"),
    "SETTINGS_UI_SCALE": ("界面缩放", "UI Scale"),
    "SETTINGS_AUDIO_SILENT": ("专属音频尚未导入，当前开发版本按要求全程静音。", "Dedicated audio has not been imported. This development build is silent by design."),
    "SETTINGS_MUSIC": ("音乐音量", "Music Volume"),
    "SETTINGS_AMBIENT": ("环境音量", "Ambient Volume"),
    "SETTINGS_INTERACTION": ("互动音量", "Interaction Volume"),
    "SETTINGS_BUBBLE_TIME": ("字幕/气泡停留时间", "Subtitle / Bubble Duration"),
    "SETTINGS_REDUCE_MOTION": ("减少动态效果", "Reduce Motion"),
    "SETTINGS_CAMERA_SHAKE": ("镜头晃动", "Camera Shake"),
    "SETTINGS_REDUCE_DESKTOP_ROAMING": ("减少桌面游走范围", "Reduce Desktop Roaming Range"),
    "SETTINGS_REDUCE_DESKTOP_ACTION_FREQUENCY": ("降低桌面动作频率", "Reduce Desktop Action Frequency"),
    "SETTINGS_DESKTOP_MUSIC": ("桌面模式也播放音乐（默认关闭）", "Play Music in Desktop Mode (Off by Default)"),
    "SETTINGS_FULLSCREEN": ("全屏", "Fullscreen"),
    "SETTINGS_LANGUAGE": ("语言", "Language"),
    "LANGUAGE_ZH_CN": ("简体中文", "Simplified Chinese"),
    "LANGUAGE_ZH_TW": ("繁体中文", "Traditional Chinese"),
    "LANGUAGE_EN": ("英语", "English"),
    "SETTINGS_SKIP_TUTORIAL": ("跳过当前新手引导", "Skip Current Tutorial"),
    "SETTINGS_HELP": ("帮助与重看教程", "Help & Replay Tutorial"),
    "SETTINGS_LEGAL": ("隐私与第三方声明", "Privacy & Third-Party Notices"),
    "HELP_CORE": ("观察猪咪的生活；点身体摸摸、点鼻子戳戳，也可投喂、布置固定插槽，并从相册观看不会错过的小剧场。所有互动都可忽略，猪咪仍会照顾好自己。", "Watch your pig live: pet the body, poke the snout, feed it, furnish fixed slots, and view never-missable memories in the album. Every interaction is optional; your pig looks after itself."),
    "HELP_DESKTOP": ("熟悉度 2 级后可进入桌面陪伴。控制点可调整停靠、缩放、置顶、动作频率、专注、暂停、隐藏、返回小屋或退出；桌面音乐默认关闭。", "Desktop Pal unlocks at Familiarity 2. Its controls cover docking, scale, always-on-top, action frequency, focus, pause, hide, room return, and exit; desktop music starts off."),
    "HELP_ALBUM": ("表情册显示线索与首次日期；生活照片可重看和导出；章节日记记录关系进展。新内容用柔和圆点提示。", "Expressions show hints and first-seen dates; life photos can be replayed and exported; the diary records your relationship. A soft dot marks new content."),
    "HELP_SAVING": ("养成进度会在重要解锁、模式切换、每 60 秒和退出时自动保存，并保留两份轮换备份。机器窗口设置不会进入跨设备存档。", "Progress auto-saves after important unlocks, mode switches, every 60 seconds, and exit, with two rotating backups. Machine window settings stay out of cross-device saves."),
    "HELP_REPLAY_NAMING": ("重新命名并重看新手引导", "Rename and Replay Tutorial"),
    "HELP_REPLAY_TUTORIAL": ("从摸摸步骤重看新手引导", "Replay Tutorial from Petting"),
    "LEGAL_PRIVACY": ("隐私：游戏没有账号、自建服务器、广告 SDK 或默认遥测，不采集个人数据。养成存档、游戏内照片、手动截图和最多 5 份滚动运行日志默认只写入本机；日志不会自动上传。启用 Steam Cloud 时，仅同步养成主档、两份安全备份和游戏自动生成的生活相册照片；手动截图、导出副本、机器/窗口设置和日志仍只留在本机。正式版和 Demo 使用互相隔离的云路径。", "Privacy: the game has no account, private server, ad SDK, or default telemetry and collects no personal data. Progress saves, in-game photos, manual screenshots, and up to five rolling runtime logs stay local by default; logs are never uploaded automatically. When Steam Cloud is enabled, it syncs only the main progression save, two safety backups, and game-generated life-album photos; manual screenshots, exported copies, machine/window settings, and logs stay local. Full game and Demo use isolated cloud paths."),
    "LEGAL_THIRD_PARTY": ("第三方：猪图形母版归档自 Google Noto Emoji 历史提交 f2a4f72bffe0212c72949a22698be235269bfab5，依据 Apache License 2.0 使用。完整许可证、来源哈希和修改说明随游戏提供。", "Third party: the pig graphic master is archived from Google Noto Emoji commit f2a4f72bffe0212c72949a22698be235269bfab5 under Apache License 2.0. The full license, source hashes, and modification notice ship with the game."),
    "LEGAL_NO_BRANDS": ("游戏内新增动作、房间、道具、包装、音乐和音效均为项目原创；不包含来源不明的旧素材或现实零食品牌。", "New actions, rooms, props, packaging, music, and sound effects are project originals. Unknown-source legacy assets and real snack brands are not included."),
    "DESKTOP_ROOM": ("小屋", "Room"),
    "DESKTOP_ROOM_HINT": ("返回完整小屋。", "Return to the full room."),
    "DESKTOP_MEMORY_BUBBLE": ("● {count} 段新回忆", "● {count} New Memories"),
    "DESKTOP_FOCUS": ("专注模式", "Focus Mode"),
    "DESKTOP_ALWAYS_ON_TOP": ("始终置顶", "Always on Top"),
    "DESKTOP_PAUSE": ("暂停/继续动画", "Pause/Resume Animation"),
    "DESKTOP_TRANSPARENT_MODE": ("透明桌面模式（关闭即普通小窗）", "Transparent Desktop Mode (Off for Normal Window)"),
    "DESKTOP_SCALE_50": ("缩放 50%", "Scale 50%"),
    "DESKTOP_SCALE_75": ("缩放 75%", "Scale 75%"),
    "DESKTOP_SCALE_100": ("缩放 100%", "Scale 100%"),
    "DESKTOP_SCALE_125": ("缩放 125%", "Scale 125%"),
    "DESKTOP_SCALE_150": ("缩放 150%", "Scale 150%"),
    "DESKTOP_DOCK_BOTTOM": ("停靠底部", "Dock Bottom"),
    "DESKTOP_DOCK_LEFT": ("停靠左侧", "Dock Left"),
    "DESKTOP_DOCK_RIGHT": ("停靠右侧", "Dock Right"),
    "DESKTOP_MINIMIZE": ("隐藏到任务栏", "Hide to Taskbar"),
    "DESKTOP_EXIT": ("完全退出", "Exit Completely"),
    "EXIT_TITLE": ("猪咪要留在哪里？", "Where Should Your Pig Stay?"),
    "EXIT_MESSAGE": ("关闭小屋时，可以让猪咪继续待在桌面，也可以和游戏一起休息。", "When closing the room, your pig can stay on the desktop or rest together with the game."),
    "EXIT_KEEP_DESKTOP": ("让猪咪留在桌面", "Keep Pig on Desktop"),
    "EXIT_ALL": ("全部退出", "Exit Everything"),
    "EXIT_CANCEL": ("先不关", "Not Yet"),
    "EXIT_SAVE_FAILED_TITLE": ("退出前要先保存吗？", "Save Before Exiting?"),
    "EXIT_SAVE_FAILED_MESSAGE": ("退出检查点没有完成。你可以重试、返回检查存储空间，或明确选择不保存并退出。", "The exit checkpoint did not finish. Retry, return to check storage, or explicitly exit without saving."),
    "EXIT_RETRY": ("重试", "Retry"),
    "EXIT_WITHOUT_SAVING": ("不保存并退出", "Exit Without Saving"),
    "SAVE_RECOVERY_TITLE": ("先找回猪咪的日常", "Recover Your Pig's Days First"),
    "SAVE_RECOVERY_MESSAGE": ("主存档和两份备份都暂时无法读取，可能损坏或来自更新版本。为了保护原文件，生活计时和进度写入已暂停，不会另存新档。请先备份此文件夹，并恢复有效存档或使用兼容版本，再重试读取：\n{path}", "The save and both backups could not be read. They may be damaged or from a newer version. Life simulation and progression writes are paused to protect the original files; no new save will replace them. Back up this folder, restore a valid save or use a compatible version, then retry:\n{path}"),
    "SAVE_RECOVERY_RETRY": ("重试读取存档", "Retry Loading Save"),
    "TOAST_PET": ("{name}：我没有走开，所以可以再摸一下。", "{name}: I did not leave, so one more pat is acceptable."),
    "TOAST_POKE": ("{name}：刚才是戳。我正在判断这算不算正式意见。", "{name}: That was a poke. I am deciding whether it counts as formal feedback."),
    "TOAST_PURCHASED": ("买下了「{item}」。", "Bought “{item}”."),
    "TOAST_BEHAVIOR_POINTS": ("{behavior} · +{points} 日常点数", "{behavior} · +{points} Daily Points"),
    "TOAST_MEMORY_WAITING": ("有一段新回忆在相册里等着。", "A new memory is waiting in the album."),
    "TOAST_LEVEL_UP": ("熟悉度升到 {level} 级。新的生活角落松动了一点。", "Familiarity reached {level}. A new corner of life opened up."),
    "TOAST_NOT_ENOUGH_POINTS": ("点数不太够。猪咪决定先不发表意见。", "Not quite enough points. Your pig has chosen not to comment."),
    "TOAST_FURNITURE_PLACED": ("「{item}」已经放好了。", "“{item}” is now in place."),
    "TOAST_FURNITURE_INVITED": ("猪咪接受了「{item}」的邀请。", "Your pig accepted the invitation from “{item}”."),
    "TOAST_PIG_PLACED": ("{name}：这里也可以，我适应得很快。", "{name}: This spot works too. I adapt quickly."),
    "TOAST_SCREENSHOT_SAVED": ("照片已保存到 {path}", "Photo saved to {path}"),
    "TOAST_SCREENSHOT_FAILED": ("照片没有保存成功。", "The photo could not be saved."),
    "TOAST_PHOTO_ADDED": ("小剧场照片已经加入生活相册。", "A memory photo was added to the life album."),
    "TOAST_PHOTO_EXPORTED": ("照片已导出到 {path}", "Photo exported to {path}"),
    "TOAST_DEMO_SAVE_IMPORTED": ("试玩进度已经安全带到正式版。", "Your demo progress was safely imported into the full game."),
    "TOAST_SAVE_RECOVERED": ("主存档有点不舒服，已经从最近的安全备份恢复。", "The main save had a problem and was restored from the latest safe backup."),
    "TOAST_SAVE_FAILED": ("这次进度没有保存成功。请检查磁盘空间或文件夹权限。", "Progress could not be saved. Please check disk space or folder permissions."),
    "TOAST_FEED": ("这份零食获得了认真点头。", "This snack received a very serious nod."),
}
for key, (zh, en) in UI.items():
    add(key, zh, en)


BEHAVIORS = {
    "behavior_idle_stand": ("站着想事情", "Standing and Thinking"), "behavior_walk": ("慢慢走两步", "A Slow Little Walk"),
    "behavior_sit": ("坐得很正式", "Sitting Very Formally"), "behavior_lie_down": ("原地趴好", "Flopping Down"),
    "behavior_sleep": ("认真睡觉", "Serious Sleeping"), "behavior_stare": ("看着空气", "Watching the Air"),
    "behavior_scratch": ("挠挠痒", "A Quick Scratch"), "behavior_look_mouse": ("研究鼠标", "Studying the Cursor"),
    "behavior_seek_food": ("寻找合理零食", "Seeking a Reasonable Snack"), "behavior_bed_nap": ("床上小睡", "Bed Nap"),
    "behavior_pillow_flop": ("扑向抱枕", "Pillow Flop"), "behavior_nightlight_gaze": ("研究夜灯", "Night-Light Gazing"),
    "behavior_blanket_roll": ("把毯子卷好", "Rolling the Blanket"), "behavior_mirror_pose": ("镜前确认状态", "Mirror Inspection"),
    "behavior_read_book": ("从书架挑一本", "Choosing a Book"), "behavior_alarm_argue": ("和闹钟讲道理", "Arguing with the Alarm"),
    "behavior_table_snack": ("桌边加餐", "Table-Side Snack"), "behavior_fridge_check": ("检查冰箱", "Checking the Fridge"),
    "behavior_drink_sip": ("小口喝饮料", "Taking a Small Sip"), "behavior_tea_brew": ("慢慢泡热饮", "Brewing Something Warm"),
    "behavior_cookie_guard": ("看守饼干罐", "Guarding the Cookie Jar"), "behavior_treadmill_run": ("稍微跑一下", "Running a Little"),
    "behavior_yoga_pose": ("摆好瑜伽姿势", "Holding a Yoga Pose"), "behavior_paint": ("认真画画", "Painting Seriously"),
    "behavior_ball_play": ("指导软球", "Coaching the Soft Ball"), "behavior_drum": ("敲两下小鼓", "Two Tiny Drum Beats"),
    "behavior_take_photo": ("寻找构图", "Finding a Composition"), "behavior_solve_puzzle": ("研究谜题盒", "Studying the Puzzle Box"),
    "behavior_castle_hide": ("巡视纸箱城堡", "Inspecting the Cardboard Castle"), "behavior_water_plant": ("给植物浇水", "Watering the Plant"),
    "behavior_radio_listen": ("听收音机", "Listening to the Radio"), "behavior_weather_watch": ("观察天气", "Watching the Weather"),
    "behavior_window_nap": ("窗边打盹", "Window-Side Nap"), "behavior_telescope": ("看看远处", "Looking Far Away"),
    "behavior_wind_chime": ("等风铃响", "Waiting for the Chime"), "behavior_robot_ride": ("乘坐扫地机器人", "Riding the Cleaning Robot"),
}
for item in json.loads((DATA / "catalog" / "behaviors.json").read_text()):
    zh, en = BEHAVIORS[item["id"]]
    add(item["name_key"], zh, en)


FURNITURE_NAMES = {
    "furn_bed_basic": ("软软小床", "Soft Little Bed"), "furn_pillow_cloud": ("云朵抱枕", "Cloud Pillow"),
    "furn_nightlight_moon": ("月亮夜灯", "Moon Night-Light"), "furn_blanket_roll": ("卷卷薄毯", "Roll-Up Blanket"),
    "furn_mirror_round": ("圆圆镜子", "Round Mirror"), "furn_bookshelf_low": ("矮矮书架", "Low Bookshelf"),
    "furn_clock_sleepy": ("困困闹钟", "Sleepy Alarm Clock"), "furn_robot_dock": ("机器人停靠点", "Robot Dock"),
    "furn_table_snack": ("零食小桌", "Snack Table"), "furn_fridge_pink": ("粉色小冰箱", "Pink Mini Fridge"),
    "furn_drink_crate": ("饮料箱", "Drink Crate"), "furn_kettle_round": ("圆肚水壶", "Round Kettle"),
    "furn_cookie_jar": ("饼干罐", "Cookie Jar"), "furn_fruit_bowl": ("水果碗", "Fruit Bowl"),
    "furn_mini_oven": ("迷你烤箱", "Mini Oven"), "furn_cleaning_robot": ("扫地机器人", "Cleaning Robot"),
    "furn_treadmill": ("短短跑步机", "Short Treadmill"), "furn_yoga_mat": ("柔软瑜伽垫", "Soft Yoga Mat"),
    "furn_easel": ("小画架", "Little Easel"), "furn_soft_ball": ("不会跑远的软球", "Stay-Close Soft Ball"),
    "furn_tiny_drum": ("小小鼓", "Tiny Drum"), "furn_camera": ("生活相机", "Everyday Camera"),
    "furn_puzzle_box": ("谜题盒", "Puzzle Box"), "furn_cardboard_castle": ("纸箱城堡", "Cardboard Castle"),
    "furn_plant_sprout": ("新芽盆栽", "Sprout Pot"), "furn_radio": ("慢声收音机", "Soft-Voice Radio"),
    "furn_weather_charm": ("天气挂件", "Weather Charm"), "furn_window_cushion": ("窗边坐垫", "Window Cushion"),
    "furn_telescope": ("短筒望远镜", "Short Telescope"), "furn_wind_chime": ("轻声风铃", "Gentle Wind Chime"),
    "furn_tea_tray": ("下午茶托盘", "Tea Tray"), "furn_tiny_lamp": ("一盏小灯", "Tiny Lamp"),
}
for item in json.loads((DATA / "furniture" / "furniture.json").read_text()):
    zh, en = FURNITURE_NAMES[item["id"]]
    add(item["name_key"], zh, en)
    category = item["category"]
    if category == "functional":
        add(item["description_key"], f"{zh}会带来一种新动作，也可能成为小剧场的条件。", f"{en} adds a new behavior and may become the condition for a memory.")
    elif category == "atmosphere":
        add(item["description_key"], f"{zh}会轻轻改变这个角落的光线和气氛。", f"{en} gently changes the light and mood of this corner.")
    else:
        add(item["description_key"], f"{zh}不提高数值，只负责让房间更像家。", f"{en} grants no numeric advantage; it simply makes the room feel more like home.")


SNACKS = {
    "snack_apple": ("脆脆苹果片", "Crisp Apple Slices", "酸甜得很诚实。", "Honestly sweet and tart."),
    "snack_berry_milk": ("莓果牛奶", "Berry Milk", "喝完留下了一圈很有学问的奶胡子。", "It left a very scholarly milk moustache."),
    "snack_cloud_bun": ("云朵小面包", "Cloud Bun", "摸起来像枕头，吃起来不是。", "It feels like a pillow and tastes unlike one."),
    "snack_crunchy_peas": ("咔嚓青豆", "Crunchy Peas", "声音很响，所以算正式吃饭。", "It is loud enough to count as a formal meal."),
    "snack_peach_soda": ("桃桃气泡水", "Peach Soda", "每个气泡都在认真工作。", "Every bubble is working very hard."),
    "snack_seaweed_roll": ("小海苔卷", "Tiny Seaweed Roll", "一口一个，便于保持严肃。", "One bite each, ideal for staying serious."),
    "snack_pudding_cup": ("晃晃布丁", "Wobbly Pudding", "它先晃，所以不是猪咪没坐稳。", "The pudding wobbled first, so it was not the pig."),
    "snack_star_cookie": ("星星饼干", "Star Cookie", "宇宙被咬掉了一个角。", "A corner of the universe has been bitten off."),
    "snack_warm_cocoa": ("暖暖可可", "Warm Cocoa", "今天的手和心情都暖了一点。", "Both paws and mood are a little warmer."),
    "snack_tiny_sandwich": ("三角小三明治", "Tiny Triangle Sandwich", "三角形更容易被认真对待。", "Triangles are easier to take seriously."),
}
for item in json.loads((DATA / "catalog" / "snacks.json").read_text()):
    zh, en, reaction_zh, reaction_en = SNACKS[item["id"]]
    add(item["name_key"], zh, en)
    add(item["description_key"], f"一份原创包装的{zh}，没有现实品牌，也没有吃错惩罚。", f"A serving of {en.lower()} in original packaging, with no real-world brand and no wrong choice.")
    add(item["reaction_key"], reaction_zh, reaction_en)


OUTFITS = {
    "outfit_berry_beret": ("莓果贝雷帽", "Berry Beret"), "outfit_round_glasses": ("圆框眼镜", "Round Glasses"),
    "outfit_cloud_scarf": ("云朵围巾", "Cloud Scarf"), "outfit_sprout_pin": ("新芽发卡", "Sprout Pin"),
    "outfit_sleepy_cap": ("困困睡帽", "Sleepy Cap"), "outfit_rain_cape": ("小雨披", "Little Rain Cape"),
    "outfit_painter_hat": ("画家帽", "Painter Hat"), "outfit_sports_band": ("运动发带", "Sports Headband"),
    "outfit_bow_tie": ("认真领结", "Serious Bow Tie"), "outfit_paper_crown": ("纸片王冠", "Paper Crown"),
    "outfit_star_glasses": ("星星眼镜", "Star Glasses"), "outfit_hero_cape": ("偶尔英雄披风", "Occasional Hero Cape"),
}
for item in json.loads((DATA / "catalog" / "outfits.json").read_text()):
    zh, en = OUTFITS[item["id"]]
    add(item["name_key"], zh, en)
    add(item["description_key"], f"把{zh}固定在对应锚点上。只改变外观，不改变养成效率。", f"Attaches the {en.lower()} to its matching anchor. Cosmetic only; it never changes progression speed.")


EVENT_COPY = {
    "event_move_in": ("搬进来", "Moving In", "猪咪检查了新家，并迅速得出这里可以住的结论。", "Your pig inspected the new home and quickly concluded it was livable.", ["我只是暂时坐在这里。暂时可以很久。", "床的位置不错。我替你试过了。", "我们可以先住下，其他事情明天再决定。"], ["I am only sitting here temporarily. Temporarily can last a long time.", "The bed is in a good spot. I tested it for you.", "We can stay first and decide everything else tomorrow."]),
    "event_fridge_meeting": ("冰箱会议", "The Fridge Meeting", "开门、思考、关门，再回来确认一次。", "Open, think, close, then return to confirm once more.", ["我在等里面长出新东西。", "第二次检查属于复核，不是贪吃。", "会议结论：冰箱需要一点时间。"], ["I am waiting for something new to grow inside.", "The second check is verification, not greed.", "Meeting conclusion: the fridge needs more time."]),
    "event_balanced_treat": ("消耗与补充", "Spend and Replenish", "跑步十秒后，一根巨大的原创冰棒及时出现。", "After ten seconds of running, an enormous original ice pop appears right on time.", ["运动后的零食，不算零食。", "消耗和补充要平衡。这个很科学。", "我不是跑累了，我只是进入补充阶段。"], ["A snack after exercise does not count as a snack.", "Spending and replenishing must balance. It is scientific.", "I am not tired. I have entered the replenishment phase."]),
    "event_cookie_detective": ("饼干侦探", "Cookie Detective", "线索从罐子一路延伸到了猪咪嘴边。", "The trail led from the jar directly to the pig's mouth.", ["我在保护证据。", "少了一块，说明嫌疑人很谨慎。", "嘴边的是侦查用碎屑。"], ["I am protecting the evidence.", "One is missing. The suspect is careful.", "The crumbs are for investigative purposes."]),
    "event_cocoa_moustache": ("可可胡子", "Cocoa Moustache", "一杯热可可带来了一圈很正式的胡子。", "A cup of cocoa created a very formal moustache.", ["成熟的猪咪都这样喝。", "这不是沾到，是一种造型。", "请等我拍完证件照再擦。"], ["Mature pigs all drink like this.", "It is not a stain. It is a style.", "Please wait until after my official photo to wipe it."]),
    "event_midnight_snack": ("午夜的小声音", "A Small Midnight Sound", "包装袋发出的声音比计划响了一点。", "The snack bag sounded slightly louder than planned.", ["我没有偷吃，我在降低库存压力。", "夜里吃的东西比较轻，不容易被发现。", "只要动作慢一点，就算安静。"], ["I am not sneaking food. I am reducing inventory pressure.", "Food is lighter at night and harder to notice.", "If I move slowly, it counts as quiet."]),
    "event_last_pea": ("最后一颗青豆", "The Last Pea", "猪咪与最后一颗青豆进行了漫长谈判。", "Your pig held a long negotiation with the final pea.", ["我不是挑食，我在尊重最后一口。", "谁先动，谁就输了。", "它看起来还没准备好被吃。"], ["I am not picky. I am respecting the final bite.", "Whoever moves first loses.", "It does not look ready to be eaten."]),
    "event_yoga_blanket": ("瑜伽的真正用途", "The True Use of Yoga", "瑜伽垫最后被证明是一条不错的被子。", "The yoga mat was ultimately proven to be a decent blanket.", ["这个姿势叫做顺势休息。", "瑜伽讲究倾听身体。身体说睡觉。", "我已经完成最难的部分：把垫子铺开。"], ["This pose is called resting with the flow.", "Yoga means listening to the body. The body said sleep.", "I finished the hardest part: unrolling the mat."]),
    "event_alarm_victory": ("早起成功", "Successful Early Rising", "闹钟响了三次，今天最难的事情终于完成。", "After three alarms, the hardest task of the day was finally complete.", ["我起来了。今天已经很成功。", "第三次才是正式通知。", "早起不是时间，是一种态度。"], ["I am up. Today is already a success.", "The third ring was the official notice.", "Early rising is an attitude, not a time."]),
    "event_pillow_migration": ("抱枕迁徙", "Pillow Migration", "云朵抱枕跟着猪咪慢慢换了三个位置。", "The cloud pillow slowly migrated through three spots with the pig.", ["不是我离不开它，是它需要陪伴。", "我在测试每个角落的柔软度。", "最后一个位置最适合先不动。"], ["I am not attached to it. It needs company.", "I am testing every corner for softness.", "The last spot is best for not moving yet."]),
    "event_dream_meeting": ("梦里开会", "A Meeting in a Dream", "猪咪睡得很认真，偶尔还点头表示同意。", "Your pig slept very seriously and occasionally nodded in agreement.", ["刚才的会议很重要，不能公开。", "我没有说梦话，我在做会议记录。", "结论是继续睡，没人反对。"], ["That meeting was important and confidential.", "I was not talking in my sleep. I was taking minutes.", "The conclusion was to keep sleeping. No objections."]),
    "event_window_nap": ("一小块阳光", "A Patch of Sunlight", "窗边的阳光刚好够放下一只睡着的猪咪。", "The patch of sun was exactly large enough for one sleeping pig.", ["我在替地板保存温度。", "太阳找到我，不是我偷懒。", "这里的光很适合把眼睛闭上。"], ["I am storing warmth for the floor.", "The sun found me. This is not laziness.", "The light here is ideal for closing one's eyes."]),
    "event_treadmill_reward": ("跑步后的奖励", "Post-Run Reward", "猪咪跑完一小段，立刻为自己颁发了休息。", "Your pig finished a short run and immediately awarded itself a rest.", ["奖励要及时，不然会失去意义。", "我没有停，我在横向运动。"], ["Rewards must be timely or they lose meaning.", "I have not stopped. I am moving horizontally."]),
    "event_one_stretch": ("只拉伸一下", "Just One Stretch", "一个拉伸动作完成后，猪咪摆出了结束姿势。", "After one stretch, your pig struck a finishing pose.", ["重点不是数量，是动作完整。", "我已经拉伸到今天。"], ["The point is completeness, not quantity.", "I have stretched all the way into today."]),
    "event_ball_coach": ("软球教练", "Coach of the Soft Ball", "猪咪对软球进行了耐心指导，球没有听懂。", "Your pig patiently coached the soft ball. The ball did not understand.", ["它需要先建立自信。", "我负责战术，球负责运动。"], ["It needs to build confidence first.", "I handle tactics. The ball handles movement."]),
    "event_heroic_lap": ("英雄的一圈", "One Heroic Lap", "猪咪完成了一圈，并为这件事戴上纸片奖牌。", "Your pig completed one lap and wore a paper medal for it.", ["英雄主义不看圈数。", "我保留体力，应对下一次英雄时刻。"], ["Heroism is not measured in laps.", "I am saving energy for the next heroic moment."]),
    "event_painting_master": ("抽象画大师", "Master of Abstract Art", "画布上出现了一团颜料，以及一份完整解释。", "A paint blob appeared on the canvas, together with a complete explanation.", ["这画的是力气回来之前的样子。", "留白很多，说明我很克制。"], ["It shows what strength looks like before it returns.", "The empty space shows great restraint."]),
    "event_plant_apology": ("给植物道歉", "An Apology to the Plant", "水浇多了一点，猪咪认真向植物解释。", "There was a little too much water, so your pig explained itself to the plant.", ["多一点是为了明天少一点。", "它点头了。或者是风。"], ["A little more today means a little less tomorrow.", "It nodded. Or that was the wind."]),
    "event_radio_dance": ("只动了两下", "Only Two Moves", "一段音乐路过，猪咪假装没有跟着晃。", "A song passed by and your pig pretended not to sway along.", ["我在校准重心。", "第二下是第一下的回声。"], ["I was calibrating my balance.", "The second move was an echo of the first."]),
    "event_robot_knight": ("扫地机器人骑士", "Knight of the Cleaning Robot", "巡视以一次撞向软垫的计划内停车结束。", "The patrol ended with a fully planned stop against a soft cushion.", ["这是计划内停车。", "骑士偶尔也需要软着陆。"], ["That was a planned stop.", "Even knights need a soft landing sometimes."]),
    "event_rainy_window": ("下雨的时候", "When It Rains", "雨落在窗外，猪咪和热饮都安静了一会儿。", "Rain fell outside while the pig and its warm drink stayed quiet together.", ["雨今天也没急着去哪。", "我们可以等云先忙完。"], ["The rain is not in a hurry today either.", "We can wait until the clouds finish being busy."]),
    "event_sunrise_watch": ("早晨经过窗边", "Morning by the Window", "太阳升起来时，猪咪刚好睁开一只眼。", "As the sun rose, your pig happened to open one eye.", ["我不是早起，我是还没完全睡回去。", "太阳先开始的。"], ["I did not wake early. I simply had not fully gone back to sleep.", "The sun started first."]),
    "event_windy_chime": ("风铃先说话", "The Chime Spoke First", "风铃响了一声，猪咪又等了很久。", "The chime rang once, and your pig waited a long time for another.", ["它只说了一半。", "我在等风组织好语言。"], ["It only said half of it.", "I am waiting for the wind to organize its thoughts."]),
    "event_ordinary_day": ("普通的一天", "An Ordinary Day", "什么大事也没发生，但相册里已经装满一起生活的证据。", "Nothing big happened, but the album is full of evidence that you lived together.", ["谢谢你陪我什么也没做。", "今天完成了一件大事：一起过完今天。"], ["Thank you for doing nothing with me.", "We finished one big thing today: getting through today together."]),
}
for event in json.loads((DATA / "events" / "events.json").read_text()):
    title_zh, title_en, summary_zh, summary_en, lines_zh, lines_en = EVENT_COPY[event["id"]]
    add(event["title_key"], title_zh, title_en)
    add(event["summary_key"], summary_zh, summary_en)
    if len(lines_zh) != len(event["variants"]) or len(lines_en) != len(event["variants"]):
        raise ValueError(f"variant copy mismatch: {event['id']}")
    for key, zh, en in zip(event["variants"], lines_zh, lines_en):
        add(key, zh, en)


EXPRESSION_NAMES = {
    "expr_happy_soft": ("软软开心", "Softly Happy", "今天也算过得很不错。", "Today turned out rather nice."),
    "expr_happy_snack": ("零食满足", "Snack Satisfaction", "这不是贪吃，是认真品尝。", "This is not greed. It is careful tasting."),
    "expr_happy_big": ("大大开心", "Big Happy", "嘴角只是临时抬高。", "The corners of my mouth rose temporarily."),
    "expr_happy_relaxed": ("安心做梦", "Peaceful Dream", "梦里的事情都按明天处理。", "Everything in the dream is scheduled for tomorrow."),
    "expr_happy_warm": ("晒得暖暖", "Sun-Warmed", "这一小块阳光归我保管。", "I will look after this patch of sun."),
    "expr_happy_giggle": ("忍住没笑", "Almost Not Laughing", "我只是呼吸得比较有节奏。", "I was only breathing rhythmically."),
    "expr_happy_sparkle": ("安静发亮", "Quiet Sparkle", "雨把窗户擦得很有气氛。", "The rain polished the window into a mood."),
    "expr_happy_ending": ("谢谢陪伴", "Thanks for Staying", "什么也没做，也一起过了很久。", "We did nothing and still spent so long together."),
    "expr_sleepy_blanket": ("垫子被子", "Mat Blanket", "用途是由使用者决定的。", "The user decides the purpose."),
    "expr_sleepy_alarm": ("闹钟以后", "After the Alarm", "醒来是一项分阶段工程。", "Waking up is a phased project."),
    "expr_sleepy_pillow": ("抱枕不离身", "Pillow Companion", "它比较需要我。", "It needs me more than I need it."),
    "expr_sleepy_dream": ("梦里点头", "Dream Nod", "会议通过了继续睡觉。", "The meeting approved more sleep."),
    "expr_sleepy_window": ("窗边融化", "Window Melt", "阳光让骨头暂时变软。", "Sunlight made my bones temporarily soft."),
    "expr_sleepy_yawn": ("拉伸附带哈欠", "Stretch with Yawn", "这是呼吸练习的一部分。", "This is part of the breathing exercise."),
    "expr_sleepy_blink": ("只睁一只眼", "One Eye Open", "另一只还在昨天。", "The other one is still in yesterday."),
    "expr_sleepy_deep": ("等风等睡着", "Waited into Sleep", "风会再来的，我先闭一下眼。", "The wind will return. I will close my eyes briefly."),
    "expr_hungry_fridge": ("冰箱期待", "Fridge Expectation", "再开一次也许会不一样。", "One more opening might change things."),
    "expr_hungry_secret": ("补充阶段", "Replenishment Phase", "运动和零食必须保持平衡。", "Exercise and snacks must stay balanced."),
    "expr_hungry_cookie": ("饼干证据", "Cookie Evidence", "我正在保护最后几块。", "I am protecting the remaining pieces."),
    "expr_hungry_cocoa": ("可可胡子", "Cocoa Moustache", "今天显得成熟了一点。", "I look a little more mature today."),
    "expr_hungry_midnight": ("午夜小口", "Midnight Bite", "夜里的库存也需要管理。", "Night inventory needs management too."),
    "expr_hungry_pea": ("青豆谈判", "Pea Negotiation", "双方仍未达成一致。", "Neither side has reached an agreement."),
    "expr_hungry_drool": ("梦见零食", "Snack Dream", "只是梦先饿了。", "Only the dream got hungry first."),
    "expr_hungry_sniff": ("闻到早饭", "Breakfast Sniff", "太阳升起通常伴随一些味道。", "Sunrise usually comes with a few smells."),
    "expr_wronged_empty_fridge": ("冰箱没配合", "Uncooperative Fridge", "它今天没有长出新东西。", "It did not grow anything new today."),
    "expr_wronged_poke": ("请尊重谈判", "Respect the Negotiation", "青豆和我还在沟通。", "The pea and I are still communicating."),
    "expr_wronged_alarm": ("第三次才算", "Third Ring Counts", "前两次只是预告。", "The first two were previews."),
    "expr_wronged_exercise": ("横向运动", "Horizontal Exercise", "躺下也有方向。", "Lying down still has direction."),
    "expr_wronged_paint": ("画有自己的想法", "The Painting Decided", "颜料选择了那个位置。", "The paint chose that spot."),
    "expr_wronged_plant": ("水多了一点", "A Little Extra Water", "我是为明天提前浇的。", "I watered in advance for tomorrow."),
    "expr_wronged_robot": ("计划内停车", "Planned Stop", "软垫突然出现在计划里。", "The cushion suddenly entered the plan."),
    "expr_wronged_rain": ("雨没有停", "Rain Kept Going", "我已经看了它很久。", "I have watched it for a very long time."),
    "expr_proud_yoga": ("顺势休息", "Resting with the Flow", "垫子已经充分发挥作用。", "The mat has fulfilled its purpose."),
    "expr_proud_treadmill": ("跑完一点", "Ran a Bit", "一点也是完整的一点。", "A little can still be a complete little."),
    "expr_proud_pose": ("结束姿势", "Finishing Pose", "完整收尾很重要。", "A complete finish matters."),
    "expr_proud_ball": ("球的教练", "Ball Coach", "战术已经讲得很清楚。", "The tactics were explained clearly."),
    "expr_proud_hero": ("一圈英雄", "One-Lap Hero", "英雄主义不看圈数。", "Heroism is not measured in laps."),
    "expr_proud_painter": ("抽象大师", "Abstract Master", "解释比画更完整。", "The explanation is more complete than the painting."),
    "expr_proud_gardener": ("提前浇水", "Advanced Watering", "这是很长远的安排。", "This is long-term planning."),
    "expr_proud_ending": ("普通日子专家", "Ordinary-Day Expert", "今天也被好好过完了。", "Today was properly lived through too."),
    "expr_shocked_new_home": ("这就住下了", "Already Moved In", "决定比行李先到。", "The decision arrived before the luggage."),
    "expr_shocked_icecream": ("补充这么大", "That Much Replenishment", "平衡偶尔需要很大的另一边。", "Balance sometimes needs a very large other side."),
    "expr_shocked_fridge": ("声音太响", "Too Loud", "包装袋没有配合潜行。", "The snack bag did not cooperate with stealth."),
    "expr_shocked_ball": ("球自己动了", "The Ball Moved", "战术居然生效了。", "The tactics somehow worked."),
    "expr_shocked_robot": ("还能再跑一圈", "Another Lap?", "纸片奖牌还没来得及休息。", "The paper medal has not rested yet."),
    "expr_shocked_music": ("身体先听见", "Body Heard First", "重心未经同意就晃了一下。", "My balance swayed without permission."),
    "expr_shocked_bump": ("软垫突袭", "Cushion Ambush", "计划刚好在撞到时更新。", "The plan updated exactly at impact."),
    "expr_shocked_weather": ("风铃说话", "The Chime Spoke", "它好像只说了一半。", "It sounded like only half a sentence."),
}
event_titles = {event_id: copy[0:2] for event_id, copy in EVENT_COPY.items()}
for item in json.loads((DATA / "expressions" / "expressions.json").read_text()):
    name_zh, name_en, line_zh, line_en = EXPRESSION_NAMES[item["id"]]
    add(item["name_key"], name_zh, name_en)
    add(item["line_key"], line_zh, line_en)
    title_zh, title_en = event_titles[item["associated_event"]]
    add(item["hint_key"], f"好像和「{title_zh}」有关。", f"It may have something to do with “{title_en}”.")


ACHIEVEMENTS = {
    "ach_welcome_home": ("住下了", "Moved In", "看完“搬进来”。", "Watch Moving In."),
    "ach_first_expression": ("第一张表情", "First Expression", "解锁第一个表情。", "Unlock your first expression."),
    "ach_first_furniture": ("家里多了一件事", "One More Thing at Home", "买下第一件家具。", "Buy your first piece of furniture."),
    "ach_familiar_2": ("开始熟悉", "Getting Familiar", "熟悉度达到 2 级。", "Reach Familiarity 2."),
    "ach_familiar_3": ("零食角开放", "Snack Nook Open", "熟悉度达到 3 级。", "Reach Familiarity 3."),
    "ach_familiar_4": ("稍微活动", "A Little Activity", "熟悉度达到 4 级。", "Reach Familiarity 4."),
    "ach_familiar_6": ("窗边的位置", "A Place by the Window", "熟悉度达到 6 级。", "Reach Familiarity 6."),
    "ach_familiar_8": ("很会生活", "Living Quite Well", "熟悉度达到 8 级。", "Reach Familiarity 8."),
    "ach_familiar_10": ("已经是家", "This Is Home", "熟悉度达到 10 级。", "Reach Familiarity 10."),
    "ach_events_4": ("四段日常", "Four Daily Moments", "看完 4 个小剧场。", "Watch 4 memories."),
    "ach_events_8": ("日子有点多", "Quite a Few Days", "看完 8 个小剧场。", "Watch 8 memories."),
    "ach_events_12": ("半本生活相册", "Half an Album", "看完 12 个小剧场。", "Watch 12 memories."),
    "ach_events_18": ("什么都发生了一点", "A Little of Everything", "看完 18 个小剧场。", "Watch 18 memories."),
    "ach_events_24": ("普通的一天", "An Ordinary Day", "看完全部 24 个核心小剧场。", "Watch all 24 core memories."),
    "ach_expressions_8": ("表情渐多", "More Faces", "解锁 8 个表情。", "Unlock 8 expressions."),
    "ach_expressions_16": ("很有表情", "Quite Expressive", "解锁 16 个表情。", "Unlock 16 expressions."),
    "ach_expressions_24": ("半册表情", "Half the Faces", "解锁 24 个表情。", "Unlock 24 expressions."),
    "ach_expressions_36": ("藏不住心情", "No Hiding That Mood", "解锁 36 个表情。", "Unlock 36 expressions."),
    "ach_expressions_48": ("每一张脸", "Every Face", "解锁全部 48 个表情。", "Unlock all 48 expressions."),
    "ach_furniture_8": ("慢慢添置", "Furnishing Slowly", "拥有 8 件家具。", "Own 8 pieces of furniture."),
    "ach_furniture_16": ("半屋办法", "Half a Room of Possibilities", "拥有 16 件家具。", "Own 16 pieces of furniture."),
    "ach_furniture_32": ("小屋齐全", "A Complete Little Home", "拥有全部 32 件家具。", "Own all 32 furniture pieces."),
    "ach_outfits_6": ("换个样子", "A Different Look", "拥有 6 套装扮。", "Own 6 outfits."),
    "ach_robot_knight": ("计划内停车", "Planned Stop", "看完“扫地机器人骑士”。", "Watch Knight of the Cleaning Robot."),
}
for item in json.loads((DATA / "catalog" / "achievements.json").read_text()):
    name_zh, name_en, desc_zh, desc_en = ACHIEVEMENTS[item["id"]]
    add(item["name_key"], name_zh, name_en)
    add(item["description_key"], desc_zh, desc_en)


LIFE_PLAN_COPY = {
    "plan_pillow_notes": (
        "枕头研究笔记", "Pillow Research", "研究怎样躺着更舒服。没有枕头也能先想想，有柔软家具就更有灵感。", "Investigate being comfortable. Thinking needs no pillow, but soft furniture helps.",
        [
            ("猪要课题", "A Very Important Pig-ject", "猪要课题：怎样躺着更舒服。研究员决定先躺好，再考虑要不要开会。", "Today's pig-ject: getting comfortable. The researcher lies down before deciding whether a meeting is necessary."),
            ("换一个角度", "Another Angle", "翻个身，问题还在，舒服也还在。这算一次重要的复核。", "Turn over: the question is still there, and so is the comfort. An important review."),
            ("高枕无猪", "Snout a Worry in the World", "本来想写高枕无忧，落笔成了高枕无猪。猪咪赶紧补上：猪在，忧不在。", "The note says: snout a worry in the world. The pillow stays. So does the pig."),
        ],
    ),
    "plan_snack_reviews": (
        "零食评测小册", "Snack Reviews", "把吃点好的想法写成小册。布置零食角，让鼻子和脑袋都慢慢参与。", "Turn pleasant snack thoughts into a booklet. A snack nook helps both nose and mind.",
        [
            ("鼻子先投票", "The Nose Votes First", "第一条评测标准：闻起来让人愿意坐下来，就已经很不错。", "First criterion: if the smell makes you want to sit down, it is already promising."),
            ("香气的边界", "Where Aroma Ends", "猪咪想了很久，暂时没有找到香气和期待之间的分界线。", "After much thought, your pig cannot quite tell where aroma ends and anticipation begins."),
            ("食不相瞒", "A Snack Judgment", "食不相瞒，猪咪对这份零食很有好感。评测结论：值得坐下来，慢慢吃。", "Not a snap judgment, but a snack judgment: worth sitting down and taking your time."),
        ],
    ),
    "plan_gentle_exercise": (
        "一点点运动记录", "A Little Movement", "找一种不累人的活动方式。活动家具会给这份慢计划更多灵感。", "Find a way to move without making it a chore. Activity furniture gives this gentle plan inspiration.",
        [
            ("先动一下", "One Small Move", "把想动一动写下来，也算给身体发了一封很短的邀请。", "Writing down a wish to move is a very short invitation to the body."),
            ("动作与停顿", "Moves and Pauses", "伸懒腰后面的停顿很重要。猪咪认为停顿也应该进入记录。", "The pause after a stretch matters. Your pig thinks pauses belong in the record, too."),
            ("猪动休息", "Piggy Takes a Breather", "猪咪决定猪动休息。这是运动计划的一部分，不是把计划忘了。", "Your pig takes a breather. This pause is part of the exercise plan, not a forgotten plan."),
        ],
    ),
    "plan_afternoon_reading": (
        "午后阅读随想", "Afternoon Reading", "给好奇心留一小页空白。书架和兴趣家具能让想法更容易冒出来。", "Leave a little blank page for curiosity. Books and hobby furniture help ideas arrive.",
        [
            ("留一页空白", "A Blank Page", "暂时不知道要写什么，也可以把这一页留给将来的自己。", "Not knowing what to write yet is a good reason to leave a page for your future self."),
            ("胸有成猪", "A Pig Picture", "猪咪在页边画了自己，称之为胸有成猪。一个字没读懂，也不耽误有自己的猪意。", "Your pig sketches itself in the margin: the pig picture. Understanding every word is optional; having an idea is not."),
            ("还想再翻一页", "One More Page", "小册合上了，好奇心没有。下一页可以等到想看的时候。", "The booklet closes. Curiosity does not. The next page can wait until you want it."),
        ],
    ),
    "plan_window_observations": (
        "窗边观察手账", "Window Notes", "给普通风景写一点注脚。窗边家具让安静的观察更有意思。", "Add little footnotes to ordinary scenery. Window furniture gives quiet observation more to notice.",
        [
            ("看见普通", "Ordinary Things", "不是每一朵云都需要有名字。经过一下，也很好。", "Not every cloud needs a name. Passing by is quite enough."),
            ("猪光宝气", "A Snoutstanding View", "阳光把耳朵照得亮亮的。猪咪宣布今天猪光宝气，窗外那朵云表示没有意见。", "Sunlight makes the ears glow. A snoutstanding view, declares your pig. The cloud raises no objection."),
            ("记住这一小段", "Keep This Little Bit", "这页没有大事。只有一个可以放心坐下来的地方。", "No grand event on this page. Only a place where it feels safe to sit down."),
        ],
    ),
    "plan_household_expedition": (
        "小屋远征备忘", "A Tiny Expedition", "把熟悉的小屋想成一张地图。玩具、机器人和望远镜带来不同路线的灵感。", "Imagine your familiar room as a map. Toys, a robot, and a telescope inspire different routes.",
        [
            ("猪持大局", "Hogging the Map", "猪咪猪持大局，把床标成出发点，也标成终点。知道怎么回来，比走多远还重要。", "Your pig is hogging the map: the bed is both start and finish. Knowing the way back matters more than going far."),
            ("换一条路线", "Another Route", "同一个房间，换个想法，就多出了一条没走过的路线。", "The same room and a different thought make a route you have never taken before."),
            ("回来写两句", "A Note on Returning", "猪咪在地图旁写下：今天的小屋还是家，而且更熟悉了一点。", "Beside the map, your pig writes: the room is still home, and a little more familiar."),
        ],
    ),
}
for plan in json.loads((DATA / "catalog" / "life_plans.json").read_text()):
    name_zh, name_en, desc_zh, desc_en, notes = LIFE_PLAN_COPY[plan["id"]]
    add(plan["name_key"], name_zh, name_en)
    add(plan["description_key"], desc_zh, desc_en)
    for entry, copy in zip(plan["entries"], notes, strict=True):
        title_zh, title_en, note_zh, note_en = copy
        add(entry["title_key"], title_zh, title_en)
        add(entry["text_key"], note_zh, note_en)


with (DATA / "localization" / "game.csv").open("w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle)
    writer.writerow(["keys", "en", "zh_CN", "zh_TW"])
    for key in sorted(rows):
        zh, tw, en = rows[key]
        writer.writerow([key, en, zh, tw])
print(f"Wrote {len(rows)} localization rows")
