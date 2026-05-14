"""
Génère des JSON lip sync placeholder (format Rhubarb) depuis le texte.
Mapping lettre Rhubarb → viseme Godot (index dans le GLB) :
  X=sil  A=PP  B=DD  C=kk  D=SS  E=CH  F=FF  G=I  H=AA

Phonèmes français simplifiés :
  voyelle ouverte (a,â,o,ô) → H
  voyelle mi (e,é,è,ê,ë)   → G (ou E selon contexte)
  voyelle fermée (i,u,y)    → G
  voyelle ronde (ou,u)      → A (arrondi proche PP)
  p,b,m                     → A  (bilabial)
  f,v                       → F
  s,z,x,c(e/i)              → D
  ch,j                      → E
  t,d,n,l                   → B
  k,g,q                     → C
  r                         → F (approximation)
  silence / ponctuation     → X
"""

import json, re, os

DIALOGUES = {
    "level1_to_2": {
        "text": "Continue, mon amour... L'enfer te regarde avancer. Chaque pas te rapproche de moi. Du purgatoire. Continue.",
        "duration": 12.227
    },
    "level2_to_3": {
        "text": "Tu résistes mieux que je ne le pensais. Ce qui t'attend... c'est plus qu'un purgatoire. C'est une réponse. Tiens bon, mon amour.",
        "duration": 12.654
    },
    "level3_to_win": {
        "text": "Tu l'as traversé. Tout ça... pour moi. Avance. Je suis là.",
        "duration": 8.984
    },
}

def char_to_phoneme(c):
    c = c.lower()
    if c in 'aâoô':     return 'H'
    if c in 'eéèêë':    return 'G'
    if c in 'iîïy':     return 'G'
    if c in 'uùûü':     return 'A'
    if c in 'pbm':      return 'A'
    if c in 'fv':       return 'F'
    if c in 'szxc':     return 'D'
    if c in 'tdnl':     return 'B'
    if c in 'kgq':      return 'C'
    if c in 'rj':       return 'E'
    return None  # consonant cluster or space → skip

def text_to_cues(text, duration):
    """Génère des mouth cues depuis le texte."""
    # Nettoyage : garder lettres + espaces/ponctuations
    cleaned = re.sub(r"[''`]", '', text)  # apostrophes → fusion

    # Extraire séquences de lettres (mots) et pauses (ponctuations/espaces)
    tokens = []
    for m in re.finditer(r"([a-zA-ZàâäéèêëîïôùûüçÀÂÄÉÈÊËÎÏÔÙÛÜÇ]+)|([.,!?…]+|\s+)", cleaned):
        word, pause = m.group(1), m.group(2)
        if word:
            tokens.append(('word', word))
        elif pause:
            plen = len(re.findall(r'[.,!?…]', pause))
            tokens.append(('pause', max(0.1, plen * 0.15)))

    # Estimer durée totale de parole (nb lettres × durée par lettre)
    letter_count = sum(len(t[1]) for t in tokens if t[0] == 'word')
    pause_total = sum(t[1] for t in tokens if t[0] == 'pause')
    speech_duration = max(0.1, duration - 0.3 - pause_total)  # 0.3s silence final
    secs_per_letter = speech_duration / max(1, letter_count)

    cues = []
    t = 0.1  # 100ms silence initial

    def add_cue(start, end, val):
        if end <= start:
            return
        # Fusionner si même valeur que le précédent
        if cues and cues[-1]['value'] == val and abs(cues[-1]['end'] - start) < 0.005:
            cues[-1]['end'] = end
        else:
            cues.append({'start': round(start, 3), 'end': round(end, 3), 'value': val})

    # Silence initial
    add_cue(0.0, t, 'X')

    for ttype, tval in tokens:
        if ttype == 'pause':
            add_cue(t, t + tval, 'X')
            t += tval
        else:  # word
            word = tval
            i = 0
            while i < len(word):
                ch = word[i]
                # Digraphes français
                if i + 1 < len(word):
                    digraph = (ch + word[i+1]).lower()
                    if digraph == 'ch':
                        ph = 'E'
                        dur = secs_per_letter * 1.5
                        add_cue(t, t + dur, ph)
                        t += dur
                        i += 2
                        continue
                    if digraph in ('ou', 'on', 'an', 'en', 'in', 'un', 'eu'):
                        ph = 'H' if digraph in ('on', 'an', 'en') else 'A'
                        dur = secs_per_letter * 1.5
                        add_cue(t, t + dur, ph)
                        t += dur
                        i += 2
                        continue

                ph = char_to_phoneme(ch)
                dur = secs_per_letter * (1.2 if ph else 0.6)
                if ph:
                    add_cue(t, t + dur, ph)
                t += dur
                i += 1

    # Silence final
    if t < duration:
        add_cue(t, duration, 'X')

    return cues


out_dir = os.path.dirname(os.path.abspath(__file__))

for key, info in DIALOGUES.items():
    cues = text_to_cues(info['text'], info['duration'])
    data = {
        "metadata": {
            "soundFile": f"{key}.wav",
            "duration": info['duration']
        },
        "mouthCues": cues
    }
    path = os.path.join(out_dir, f"{key}.json")
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"Généré : {key}.json  ({len(cues)} cues)")
