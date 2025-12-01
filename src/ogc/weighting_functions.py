import logging
import subprocess
import json
import os
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.aquainfra-usecase-elbe.src.ogc.docker_utils")

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class WeightingFunctionsProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'aquainfra-elbe-usecase-image:20251201'
        self.script_name = 'weighting_functions.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<WeightingFunctionsProcessor> {self.name}'

    def execute(self, data, outputs=None):
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as configFile:
            configJSON = json.load(configFile)
            self.docker_executable = configJSON["docker_executable"]
            self.download_dir = configJSON["download_dir"].rstrip('/')
            self.download_url = configJSON["download_url"].rstrip('/')

        # Where to store output data (will be mounted read-write into container):
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.my_job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.my_job_id}'
        os.makedirs(output_dir, exist_ok=True)

        # User inputs
        in_inputFile_tif = data.get('inputFile1_tif')
        in_inputFile_gpkg = data.get('inputFile2_gpkg')
        in_inputFile_dbf = data.get('inputFile3_dbf')

        # Check user inputs
        if in_inputFile_tif is None:
            raise ProcessorExecuteError('Missing parameter "inputFile1_tif". Please provide a inputFile1_tif.')
        if in_inputFile_gpkg is None:
            raise ProcessorExecuteError('Missing parameter "inputFile2_gpkg". Please provide a inputFile2_gpkg.')
        if in_inputFile_dbf is None:
            raise ProcessorExecuteError('Missing parameter "inputFile3_dbf". Please provide a inputFile3_dbf.')

        # Where to store output data
        downloadfilename1 = 'weight_table-%s.csv' % self.my_job_id
        downloadfilename2 = 'weight_table-%s.rds' % self.my_job_id
        downloadfilepath1 = f'{output_dir}/{downloadfilename1}'
        downloadfilepath2 = f'{output_dir}/{downloadfilename2}'
        downloadlink1     = f'{output_url}/{downloadfilename1}'
        downloadlink2     = f'{output_url}/{downloadfilename2}'

        # Assemble args for script:
        script_args = [
            in_inputFile_tif,
            in_inputFile_gpkg,
            in_inputFile_dbf,
            downloadfilepath1,
            downloadfilepath2
        ]

        # Run docker container:
        returncode, stdout, stderr, user_err_msg = docker_utils.run_docker_container(
            self.docker_executable,
            self.image_name,
            self.script_name,
            output_dir,
            script_args
        )

        if not returncode == 0:
            user_err_msg = "no message" if len(user_err_msg) == 0 else user_err_msg
            err_msg = 'Running docker container failed: %s' % user_err_msg
            raise ProcessorExecuteError(user_msg = err_msg)

        else:

            # Return link to file:
            response_object = {
                "outputs": {
                    "weight_table_csv": {
                        "title": self.metadata['outputs']['weight_table_csv']['title'],
                        "description": self.metadata['outputs']['weight_table_csv']['description'],
                        "href": f'{downloadlink1}'
                    },
                    "weight_table_rds": {
                        "title": self.metadata['outputs']['weight_table_rds']['title'],
                        "description": self.metadata['outputs']['weight_table_rds']['description'],
                        "href": f'{downloadlink2}'
                    }
                }
            }

            return 'application/json', response_object


