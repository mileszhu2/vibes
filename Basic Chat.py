import random

def chat(file: str, start: str, context: int, size: int) -> str:
    f = open(file, 'r')
    l = f.readline()
    words_list = []
    while l != '':
        a = l.split(' ')
        for word in a:
            words_list.append(word)
        l = f.readline()
    f.close()
    while '' in words_list:
        words_list.remove('')

    words_dict = {}
    i = 0
    if i >= len(words_list) - context:
        return 'context too big for file'
    while i < len(words_list) - context:
        j = i + context
        phrase = words_list[i:j]
        words = ''
        for word in phrase:
            words = words + word + ' '
        words = words.rstrip(' ')
        if words not in words_dict:
            words_dict[words] = []
        if words_list[j] not in words_dict[words]:
            words_dict[words].append(words_list[j])
        i = i + 1

    text = ''
    x = 1
    if not start:
        start = random.choice(list(words_dict.keys()))
    if start in words_dict:
        text = text + start + ' '
    elif start + '\n' in words_dict:
        start = start + '\n'
        text = text + start + ' '
    else:
        return 'invalid starting word'
    while x <= size:
        next_word = random.choice(words_dict[start])
        next_start = ((start.split(' '))[1:])
        start = ''
        for word in next_start:
            start = start + word + ' '
        start = start + next_word
        if start in words_dict:
            text = text + next_word + ' '
        else:
            return 'invalid starting word'
        x = x + 1

    return text

if __name__ == "__main__":
    filename = "sample_text/alice.txt"
    print(filename)
    prompt = 'Alice was soon'
    print(chat(filename, prompt, 3, 500))
