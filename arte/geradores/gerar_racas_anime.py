"""Gera um retrato por raça (e variantes Peluvianim) no ComfyUI local (pixelPerfect_v20).
Fundo magenta chapado (#ff00ff — nenhuma raça usa magenta) + contorno preto grosso = recorte fácil.
Saída: ComfyUI/output/raca_<id>_s<seed>.png"""
import json, sys, urllib.request

ESTILO = ("masterpiece, best quality, very aesthetic, semi-realistic anime style, dark fantasy, realistic body proportions, small head, "
          "mature adult, solo, upper body, "
          "cowboy shot, waist-up portrait, full shoulders and arms visible, front view, facing viewer, symmetrical pose, centered, looking at viewer, thick black outline, simple background, plain flat dark grey background, ")
NEG = ("worst quality, low quality, blurry, text, watermark, signature, multiple people, gradient background, "
       "detailed background, scenery, snout, muzzle, animal face, elongated skull, nsfw, chibi, child, loli, shota, "
       "pink, magenta, purple tint, pink clothes, green background, white background, blue background, black background, gradient background, three-quarter view, side view, "
       "religious symbols, cross, sexualized, cleavage, long elf ears, horizontal ears, blue skin, fully scaled body, round pupils")

RACAS = {
    # Rhosanim — pálidos, cabelo branco sedoso, raiz da cor da pele, pontas podem variar
    'rhosanih': "1girl, adult elf woman, very pale skin, long straight silky white hair, hair roots same pale color as skin, "
                "pure white hair from root to tip, (slightly pointed small ears close to the head:1.2), "
                "yellow eyes, serene expression, elegant white and gold robe with leaf embroidery",
    # Dravhinim — humanos; arquivista de campo (capa verde)
    'dravhin':  "1boy, adult man late 20s, mature face, human, round ears, defined jaw, short messy brown hair, light stubble, brown eyes, confident smile, "
                "leather armor, green hooded cloak, grey seal badge on left shoulder, sword hilt behind shoulder",
    # Peluvianim — bestial (furry humanizado)
    'peluvia_bestial': "1girl, adult woman, wolf ears, wolf tail, human face, small fangs, (bare forearms covered with grey wolf fur:1.2), rolled-up sleeves, tan skin, "
                       "long braided grey hair, amber eyes, fur-trimmed hunter outfit, bow on back",
    # Peluvianim — pesado (tipo orc)
    'peluvia_pesado':  "1boy, large muscular adult man, orc-like, human nose, thick green skin, short lower tusks, human face, black topknot, "
                       "heavy fur cloak, leather straps, battle axe on shoulder, calm gentle eyes",
    # Peluvianim — escamado
    'peluvia_escamado': "1girl, adult woman, human face, (normal human skin tone:1.3), (scattered patches of teal scales on cheekbones, neck and forearms only:1.3), "
                        "(vertical slit pupils, reptile eyes:1.2), green eyes, "
                        "short black hair, light leather armor, spear",
    # Igramin — anões
    'igramir':  "1boy, short stocky dwarf, very wide, broad shoulders, thick arms, long braided red beard with iron rings, bald head, "
                "glowing blue rune tattoos, heavy steel plate armor, warhammer, grumpy expression",
}
SEEDS = (35001, 35002)

def run(rid, prompt, seed):
    wf = {"1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "Animagine_XL_3.1.safetensors"}},
          "2": {"class_type": "CLIPTextEncode", "inputs": {"text": ESTILO + prompt, "clip": ["1", 1]}},
          "3": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["1", 1]}},
          "4": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
          "5": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 28, "cfg": 6.5, "sampler_name": "euler_ancestral",
                "scheduler": "normal", "denoise": 1.0, "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}},
          "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
          "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": f"racaA_{rid}_s{seed}"}}}
    urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:8188/prompt", json.dumps({"prompt": wf}).encode(),
                                                  {"Content-Type": "application/json"})).read()

if __name__ == '__main__':
    only = sys.argv[1:] or list(RACAS)
    for rid in only:
        for s in SEEDS: run(rid, RACAS[rid], s)
    print('enfileirado', len(only) * len(SEEDS))
