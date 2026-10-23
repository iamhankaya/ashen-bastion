shader_type canvas_item;
// Yer gölgesi MultiMesh'i: örnek alfası (COLOR.a, tamponda 0,38) kazançla çarpılır; doku alfası zaten COLOR'da.
// Tampon değeri sözleşme/kabul testlerinde sabittir; okunurluk (V-01) kazançla sağlanır.
uniform float gain = 1.8;

void fragment() {
	COLOR.a = min(COLOR.a * gain, 1.0);
}
