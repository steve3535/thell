FROM python:alpine3.18  
COPY requirements.txt .
RUN pip install -r requirements.txt  
RUN mkdir templates 
COPY templates/index.html ./templates/index.html
COPY app.py .
ENTRYPOINT ["python", "./app.py"]