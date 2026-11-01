"""Конвертирует XML Tanzil в компактные файлы приложения.

Тексты не изменяются: каждая строка — дословный текст аята.
Блоки копирайта Tanzil переносятся в начало файлов (строки с '#').
Использование: python3 -I tools/build_quran_data.py <папка с XML> <папка вывода>
"""
import html, json, re, sys
from pathlib import Path

RU_TRANSLIT = """Аль-Фатиха|Аль-Бакара|Али Имран|Ан-Ниса|Аль-Маида|Аль-Анам|Аль-Араф|Аль-Анфаль|Ат-Тауба|Юнус|Худ|Юсуф|Ар-Раад|Ибрахим|Аль-Хиджр|Ан-Нахль|Аль-Исра|Аль-Кахф|Марьям|Та Ха|Аль-Анбийа|Аль-Хаджж|Аль-Муминун|Ан-Нур|Аль-Фуркан|Аш-Шуара|Ан-Намль|Аль-Касас|Аль-Анкабут|Ар-Рум|Лукман|Ас-Саджда|Аль-Ахзаб|Саба|Фатыр|Йа Син|Ас-Саффат|Сад|Аз-Зумар|Гафир|Фуссылат|Аш-Шура|Аз-Зухруф|Ад-Духан|Аль-Джасия|Аль-Ахкаф|Мухаммад|Аль-Фатх|Аль-Худжурат|Каф|Аз-Зарийат|Ат-Тур|Ан-Наджм|Аль-Камар|Ар-Рахман|Аль-Вакиа|Аль-Хадид|Аль-Муджадала|Аль-Хашр|Аль-Мумтахана|Ас-Сафф|Аль-Джумуа|Аль-Мунафикун|Ат-Тагабун|Ат-Талак|Ат-Тахрим|Аль-Мульк|Аль-Калам|Аль-Хакка|Аль-Мааридж|Нух|Аль-Джинн|Аль-Муззаммиль|Аль-Муддассир|Аль-Кийама|Аль-Инсан|Аль-Мурсалят|Ан-Наба|Ан-Назиат|Абаса|Ат-Таквир|Аль-Инфитар|Аль-Мутаффифин|Аль-Иншикак|Аль-Бурудж|Ат-Тарик|Аль-Аля|Аль-Гашия|Аль-Фаджр|Аль-Балад|Аш-Шамс|Аль-Лайль|Ад-Духа|Аш-Шарх|Ат-Тин|Аль-Алак|Аль-Кадр|Аль-Баййина|Аз-Зальзаля|Аль-Адийат|Аль-Кариа|Ат-Такасур|Аль-Аср|Аль-Хумаза|Аль-Филь|Курайш|Аль-Маун|Аль-Каусар|Аль-Кафирун|Ан-Наср|Аль-Масад|Аль-Ихлас|Аль-Фалак|Ан-Нас""".split("|")

RU_MEANING = """Открывающая|Корова|Семейство Имрана|Женщины|Трапеза|Скот|Преграды|Трофеи|Покаяние|Юнус|Худ|Юсуф|Гром|Ибрахим|Аль-Хиджр|Пчёлы|Перенёс ночью|Пещера|Марьям|Та Ха|Пророки|Паломничество|Верующие|Свет|Различение|Поэты|Муравьи|Рассказ|Паук|Румы|Лукман|Поклон|Союзники|Саба|Творец|Йа Син|Выстроившиеся в ряды|Сад|Толпы|Прощающий|Разъяснены|Совет|Украшения|Дым|Коленопреклонённые|Пески|Мухаммад|Победа|Комнаты|Каф|Рассеивающие|Гора|Звезда|Месяц|Милостивый|Падающее|Железо|Препирательство|Сбор|Испытуемая|Ряды|Собрание|Лицемеры|Взаимное обделение|Развод|Запрещение|Власть|Письменная трость|Неизбежное|Ступени|Нух|Джинны|Закутавшийся|Завернувшийся|Воскресение|Человек|Посылаемые|Весть|Вырывающие|Нахмурился|Скручивание|Раскалывание|Обвешивающие|Разверзнется|Созвездия|Ночной путник|Всевышний|Покрывающее|Заря|Город|Солнце|Ночь|Утро|Раскрытие|Смоковница|Сгусток|Предопределение|Ясное знамение|Землетрясение|Мчащиеся|Великое бедствие|Страсть к приумножению|Предвечернее время|Хулитель|Слон|Курайшиты|Мелочь|Изобилие|Неверующие|Помощь|Пальмовые волокна|Очищение веры|Рассвет|Люди""".split("|")

assert len(RU_TRANSLIT) == 114 and len(RU_MEANING) == 114

def read_ayas(path):
    s = path.read_text(encoding="utf-8")
    comments = re.findall(r"<!--(.*?)-->", s, re.S)
    ayas = []
    for sm in re.finditer(r'<sura index="(\d+)"[^>]*>(.*?)</sura>', s, re.S):
        for am in re.finditer(r'<aya index="(\d+)" text="([^"]*)"', sm.group(2)):
            text = html.unescape(am.group(2))
            assert "\n" not in text
            ayas.append(text)
    assert len(ayas) == 6236, (path, len(ayas))
    return comments, ayas

def write(out, name, comments, ayas):
    header = []
    for block in comments:
        for line in block.strip("\n").splitlines():
            line = line.rstrip()
            header.append(line if line.startswith("#") else "# " + line)
    (out / name).write_text("\n".join(header + ayas) + "\n", encoding="utf-8")

# Начало, после которого аят — продолжение мысли (из ТЗ + близкие по смыслу).
CONTINUATION_STARTS = {"и", "а", "но", "тогда", "или", "который", "которая", "которое", "которые", "которого",
    "которой", "которых", "которым", "которому", "которыми", "чтобы", "кроме", "затем", "потом", "либо",
    "ибо", "дабы", "или же", "да", "пока"}
CONTINUATION_PHRASES = ("после того",)
TERMINAL = ".!?…"
QUOTES = "»\"“”)'"

def first_word(text):
    stripped = text.lstrip("«\"„“-— ([")
    word = re.split(r"[\s,.:;!?»\"]", stripped, maxsplit=1)[0]
    return word.lower(), stripped

def ends_sentence(text):
    t = text.rstrip().rstrip(QUOTES).rstrip()
    return bool(t) and t[-1] in TERMINAL

def starts_sentence(text, previous):
    word, stripped = first_word(text)
    if previous is not None and not ends_sentence(previous):
        return False
    if word in CONTINUATION_STARTS or stripped.lower().startswith(CONTINUATION_PHRASES):
        return False
    return bool(stripped) and not stripped[0].islower()

def flags(ayas, suras):
    """'0'..'3': бит 1 — начинает предложение, бит 2 — заканчивает. Самостоятельный = 3."""
    starts = {s["start"] for s in suras}
    result = []
    for i, text in enumerate(ayas):
        previous = None if i in starts else ayas[i - 1]
        value = (1 if starts_sentence(text, previous) else 0) | (2 if ends_sentence(text) else 0)
        result.append(str(value))
    return "".join(result)

def main(src, out):
    src, out = Path(src), Path(out)
    meta = (src / "quran-data.xml").read_text(encoding="utf-8")
    suras = []
    for i, m in enumerate(re.finditer(r"<sura ([^>]*)/>", meta)):
        a = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        suras.append({"n": int(a["index"]), "ayas": int(a["ayas"]), "start": int(a["start"]),
                      "ar": a["name"], "ru": RU_TRANSLIT[i], "meaning": RU_MEANING[i],
                      "type": "Мекканская" if a["type"] == "Meccan" else "Мединская"})
        if len(suras) == 114:
            break
    assert len(suras) == 114 and suras[-1]["start"] + suras[-1]["ayas"] == 6236
    (out / "suras.json").write_text(json.dumps(suras, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    for xml, name in [("quran-uthmani.xml", "quran-uthmani.txt"), ("ru.kuliev.xml", "ru.kuliev.txt"),
                      ("ru.osmanov.xml", "ru.osmanov.txt"), ("ru.krachkovsky.xml", "ru.krachkovsky.txt")]:
        comments, ayas = read_ayas(src / xml)
        write(out, name, comments, ayas)
        print(name, len(ayas))
        if name.startswith("ru."):
            f = flags(ayas, suras)
            (out / name.replace(".txt", ".flags")).write_text(f, encoding="utf-8")
            report(name, ayas, f, suras)

def report(name, ayas, f, suras):
    total = len(f)
    standalone = f.count("3")
    print(f"  самостоятельных: {standalone} из {total} ({standalone * 100 // total}%), "
          f"начинают предложение: {sum(c in '13' for c in f)}, заканчивают: {sum(c in '23' for c in f)}")
    def ref(i):
        s = [x for x in suras if x["start"] <= i][-1]
        return f"{s['n']}:{i - s['start'] + 1}"
    for label, cond in (("самостоятельные", "3"), ("продолжение (не начинает)", "02"), ("не закончен", "01")):
        samples = [i for i, c in enumerate(f) if c in cond][::400][:4]
        for i in samples:
            print(f"    [{label}] {ref(i)}: {ayas[i][:90]}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
