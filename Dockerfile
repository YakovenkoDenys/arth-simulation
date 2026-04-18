# Використовуємо офіційний образ Python
FROM python:3.10-slim

# Встановлюємо системні пакети, необхідні для psycopg2 та OSMnx
RUN apt-get update && apt-get install -y \
    libpq-dev gcc g++ \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

# Встановлюємо робочу папку всередині контейнера
WORKDIR /app

# Копіюємо файл зі списком бібліотек
COPY requirements.txt .

# Встановлюємо бібліотеки
RUN pip install --no-cache-dir -r requirements.txt

# Копіюємо всі інші файли (твій server.py та інші)
COPY . .

# Відкриваємо порт, на якому працює Flask
EXPOSE 5000

# Команда для запуску сервера
CMD ["python", "server.py"]
