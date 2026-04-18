import math
from flask import Flask, jsonify, send_file
import psycopg2
from flask_cors import CORS
import requests
import io
import osmnx as ox
import json 
import os

 # Додаємо цей імпорт
app = Flask(__name__)
CORS(app) # Дозволяє Godot підключатися

# Твої дані від бази (ті, що ми налаштували в Docker)
# Цей рядок автоматично вибере: або адресу з інтернету, або твою локальну базу
DATABASE_URL = os.environ.get('DATABASE_URL', "postgresql://earth_master:super_secret_password_99@127.0.0.1:5433/earth_database")

def get_connection():
    # Підключення за допомогою єдиного рядка (URL)
    return psycopg2.connect(DATABASE_URL)

@app.route('/get_objects', methods=['GET'])
def get_objects():
    try:
        conn = get_connection()
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



@app.route('/get_map/<int:z>/<int:x>/<int:y>.png')
def get_map(z, x, y):
    # Формуємо URL до реальних карт OSM
    url = f"https://tile.openstreetmap.org/{z}/{x}/{y}.png"
    
    headers = {'User-Agent': 'EarthSimApp/1.0'}
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            return send_file(io.BytesIO(response.content), mimetype='image/png')
        else:
            return f"OSM Error: {response.status_code}", response.status_code
    except Exception as e:
        return str(e), 500




@app.route('/get_height/<int:z>/<int:x>/<int:y>.png')
def get_height(z, x, y):
    # Те саме посилання, яке ти перевірив у браузері
    url = f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
    headers = {'User-Agent': 'EarthSimApp/1.0'}
    try:
        response = requests.get(url, headers=headers, timeout=10)
        return send_file(io.BytesIO(response.content), mimetype='image/png')
    except Exception as e:
        return str(e), 500

@app.route('/import_capitals')
def import_capitals():
    try:
        # Прямий запит до Overpass API
        url = "https://overpass.openstreetmap.ru/api/interpreter"
        query = '[out:json];node["capital"="yes"]["admin_level"="2"];out body;'
        
        print("Завантаження столиць через прямий запит...")
        response = requests.get(url, params={'data': query}, timeout=30)
        data = response.json()
        
        conn = get_connection()
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
        
        conn = get_connection()
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
    # Порт береться з налаштувань сервера або ставиться 5000 за замовчуванням
    port = int(os.environ.get("PORT", 5000))
    print(f"Сервер запущено на порту {port}")
    app.run(host='0.0.0.0', port=port)

