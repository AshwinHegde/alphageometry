# Use an official Python base image that allows us to avoid manually installing Python
FROM python:3.10.9

# Install dependencies required for pyenv and other operations
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip

# Install gdown for downloading from Google Drive
RUN pip install gdown

# Clone the meliad library
RUN mkdir -p /meliad_lib/meliad && \
    git clone https://github.com/google-research/meliad /meliad_lib/meliad

# Set the PYTHONPATH to include the meliad library
ENV PYTHONPATH "${PYTHONPATH}:/meliad_lib/meliad"

# Copy the requirements.txt file into the container
COPY requirements.txt /app/requirements.txt

# Set the working directory
WORKDIR /app

# tensorflow-text incompatible with apple m1
# Download and install the .whl file directly
RUN curl -O https://github.com/sun1638650145/Libraries-and-Extensions-for-TensorFlow-for-Apple-Silicon/releases/download/v2.13/tensorflow_text-2.13.0-cp310-cp310-macosx_11_0_arm64.whl
RUN pip install tensorflow_text-2.13.0-cp310-cp310-macosx_11_0_arm64.whl

# Install Python dependencies from the requirements file
RUN pip install --require-hashes -r requirements.txt
# RUN pip install -r requirements.txt

# Download the data folder from Google Drive
RUN gdown --folder https://bit.ly/alphageometry && \
    mv ag_ckpt_vocab /app

# Define environment variables used in the script
ENV DATA /app/ag_ckpt_vocab
ENV MELIAD_PATH /meliad_lib/meliad
ENV BATCH_SIZE 2
ENV BEAM_SIZE 2
ENV DEPTH 2

# Copy the rest of the application's code into the container
COPY . /app

# Command to run the application
CMD ["python", "-m", "alphageometry", \
     "--alsologtostderr", \
     "--problems_file=/app/examples.txt", \
     "--problem_name=orthocenter", \
     "--mode=alphageometry", \
     "--defs_file=/app/defs.txt", \
     "--rules_file=/app/rules.txt", \
     "--beam_size=$BEAM_SIZE", \
     "--search_depth=$DEPTH", \
     "--ckpt_path=$DATA", \
     "--vocab_path=$DATA/geometry.757.model", \
     "--gin_search_paths=$MELIAD_PATH/transformer/configs", \
     "--gin_file=base_htrans.gin", \
     "--gin_file=size/medium_150M.gin", \
     "--gin_file=options/positions_t5.gin", \
     "--gin_file=options/lr_cosine_decay.gin", \
     "--gin_file=options/seq_1024_nocache.gin", \
     "--gin_file=geometry_150M_generate.gin", \
     "--gin_param=DecoderOnlyLanguageModelGenerate.output_token_losses=True", \
     "--gin_param=TransformerTaskConfig.batch_size=$BATCH_SIZE", \
     "--gin_param=TransformerTaskConfig.sequence_length=128", \
     "--gin_param=Trainer.restore_state_variables=False"]
