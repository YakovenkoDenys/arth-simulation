import math
from flask import Flask, jsonify, send_file
import psycopg2
from flask_cors import CORS
import requests
import io
import osmnx as ox
import json  # Додаємо цей імпорт
app = Flask(__name__)
CORS(app) # Дозволяє Godot підключатися

# Твої дані від бази (ті, що ми налаштували в Docker)
DB_CONFIG = {
    "host": "127.0.0.1",
    "port": "5433",
    "database": "earth_database",
    "user": "earth_master",
    "password": "super_secret_password_99"
}

@app.route('/get_objects', methods=['GET'])
def get_objects():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        # Запитуємо назву та координати у форматі тексту
        cur.execute("SELECT name, category, ST_AsText(location) FROM world_objects;")
        rows = cur.fetchall()
        
        results = []
        for r in rows:
            results.append({
                "name": r[0],
                "type": r[1],
                "pos": r[2] # Це поверне "POINT(30.52 50.45)"
            })
        
        cur.close()
        conn.close()
        return jsonify(results)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/get_map')
def get_map():
    # Координати Майдану
    lat, lon, z = 50.4501, 30.5234, 16
    
    # Математичний розрахунок номера тайла (квадрата)
    lat_rad = math.radians(lat)
    n = 2.0 ** z
    x = int((lon + 180.0) / 360.0 * n)
    y = int((1.0 - math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi) / 2.0 * n)
    
    url = f"https://tile.openstreetmap.org/{z}/{x}/{y}.png"
    headers = {'User-Agent': 'EarthSimApp/1.0'}
    
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return send_file(io.BytesIO(response.content), mimetype='image/png')
    return jsonify({"error": "failed"}), 404

@app.route('/import_capitals')
def import_capitals():
    try:
        # Прямий запит до Overpass API
        url = "https://overpass.openstreetmap.ru/api/interpreter"
        query = '[out:json];node["capital"="yes"]["admin_level"="2"];out body;'
        
        print("Завантаження столиць через прямий запит...")
        response = requests.get(url, params={'data': query}, timeout=30)
        data = response.json()
        
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        count = 0
        for element in data.get('elements', []):
            name = element.get('tags', {}).get('name', 'Unknown City')
            lon = element.get('lon')
            lat = element.get('lat')
            
            cur.execute("""
                INSERT INTO world_objects (name, category, location)
                VALUES (%s, %s, ST_SetSRID(ST_Point(%s, %s), 4326))
                ON CONFLICT DO NOTHING;
            """, (name, 'capital', lon, lat))
            count += 1
            
        conn.commit()
        cur.close()
        conn.close()
        return f"Успішно імпортовано {count} столиць світу!"
    except Exception as e:
        print(f"Помилка: {e}")
        return str(e), 500





@app.route('/import_area/<float:lat>/<float:lon>/<int:dist>')
def import_area(lat, lon, dist):
    try:
        # 1. Завантажуємо будівлі з OpenStreetMap для вказаної точки
        print(f"Завантаження будівель для {lat}, {lon}...")
        buildings = ox.features_from_point((lat, lon), tags={'building': True}, dist=dist)
        
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        count = 0
        for _, row in buildings.iterrows():
            name = row.get('name', 'Unknown Building')
            # Отримуємо центр будівлі для простоти
            center = row['geometry'].centroid
            
            # 2. Записуємо в нашу базу PostgreSQL
            cur.execute("""
                INSERT INTO world_objects (name, category, location, data)
                VALUES (%s, %s, ST_SetSRID(ST_Point(%s, %s), 4326), %s)
                ON CONFLICT DO NOTHING;
            """, (name, 'building', center.x, center.y, json.dumps({"source": "osm"})))
            count += 1
            
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "success", "imported": count})
    except Exception as e: 
        return jsonify({"error": str(e)}), 500
# ЦЕЙ БЛОК ЗАВЖДИ В САМОМУ КІНЦІ
if __name__ == '__main__':
    print("Сервер симуляції запущено на http://127.0.0.1:5000")
    app.run(host='0.0.0.0', port=5000)
