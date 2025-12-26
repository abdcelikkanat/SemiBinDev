import torch
from torch.utils.data import DataLoader
from torch.optim import lr_scheduler
import sys
from .semi_supervised_model import Semi_encoding_single, Semi_encoding_multiple, feature_Dataset
from .utils import norm_abundance
from .semi_supervised_model import model_load
import os

def loss_function(embedding1, cov1, embedding2, cov2, label, include_std=False):

    if not include_std:

        relu = torch.nn.ReLU()
        d = torch.norm(embedding1 - embedding2, p=2, dim=1)
        square_pred = torch.square(d)
        margin_square = torch.square(relu(1 - d))
        supervised_loss = torch.mean(label * square_pred + (1 - label) * margin_square)

        return supervised_loss

    else:
        relu = torch.nn.ReLU()

        cov1, cov2 = cov1.double(), cov2.double()

        # Compute the term (m_i - m_j)^2
        d = ( (embedding1 - embedding2)**2 * (0.25 / (cov1 + cov2 + 1e-8)) ).sum(dim=1)

        square_pred = torch.square(d)
        margin_square = torch.square(relu(1 - d))
        supervised_loss = torch.mean(label * square_pred + (1 - label) * margin_square)

        return supervised_loss


def train_self(
        output, logger, datapaths, data_splits, is_combined=True,
        batchsize=2048, epoches=15, device=None, num_process = 8, mode = 'single',
        quality_report_file_path=None, contig_bins_file=None
):
    """
    Train model from one sample(mode=single) or several samples(mode=several)

    Saves model to disk and returns it

    Parameters
    ----------
    out : filename to write model to
    """
    print(f"+ DEBUG:Training:3.1:(self_supervised_model.py): inside the train_self() function.")

    from tqdm import tqdm
    import pandas as pd
    import numpy as np

    #################################################################
    # If the quality file and output_bins_folder is given, we'll construct the pairs based on the
    if quality_report_file_path is not None or contig_bins_file is not None:
        # Check both of them is set at the same time
        assert quality_report_file_path is not None and contig_bins_file is not None, \
            "Quality file and bins folder are not provided."

        print(f"\t+ DEBUG:Training:3.1.1:(self_supervised_model.py): Refining is being used.")

        # Construct the bin2quality dictionary by reading the output of CheckM2 file (tsv file)
        qr =  pd.read_csv(quality_report_file_path, sep='\t')
        name_list = qr[['Name', 'Completeness', 'Contamination']].values.tolist()
        bin_names, completeness, contamination = map(list, zip(*name_list))
        bin2quality = dict(zip(bin_names, ''*len(bin_names)))
        for bin, comp_score, contam_score in zip(bin_names, completeness, contamination):
            if comp_score > 90 and contam_score < 5:
                bin2quality[bin] = 'HQ'
            else:
                if comp_score > 50 and contam_score < 10:
                    bin2quality[bin] = 'MQ'
                else:
                    bin2quality[bin] = 'LQ'
        bin2quality['SemiBin_-1'] = 'LQ' # Add this element in order to be consistent with bin2contigs

        # Construct the bin2contigs dictionary
        with open(contig_bins_file, 'r') as f:
            cb = pd.read_csv(f, sep='\t')
            bin2contigs = cb.groupby('bin')['contig'].apply(list).to_dict()
        # Add 'SemiBin_' keywprd to the keys
        bin2contigs = {f"SemiBin_{key}": val for key, val in bin2contigs.items()}

        # print(len(bin2quality), len(bin2contigs))
        # print(
        #     len(set(bin2quality.keys()).intersection(set(bin2contigs.keys())))
        # )
        # print(list(bin2quality.keys())[:3])
        # print(list(bin2contigs.keys())[:3])
        # raise ValueError("stop", )

    else:
        print(f"\t+ DEBUG:Training:3.1.1:(self_supervised_model.py): There will be no refining.")

    #################################################################

    train_data = pd.read_csv(datapaths[0], index_col=0).values

    print(f"+ DEBUG:Training:3.2:(self_supervised_model.py): is_combined: {is_combined}")
    if not is_combined:
        train_data = train_data[:, :136]

    torch.set_num_threads(num_process)

    logger.info('Training model...')

    if not is_combined:
        print(f"+ DEBUG:Training:3.3:(self_supervised_model.py): Model class call.")
        model = Semi_encoding_single(train_data.shape[1])
    else:
        raise NotImplementedError(f"+ DEBUG:SingleEasyBinning:No role!")
        model = Semi_encoding_multiple(train_data.shape[1])

    model = model.to(device)

    model_params = []
    for name, param in model.named_parameters():
        param.requires_grad = True
        model_params.append(param)

    optimizer = torch.optim.Adam(model_params, lr=1e-3)
    # optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
    scheduler = lr_scheduler.StepLR(optimizer, step_size=1, gamma=0.9)

    print(f"+ DEBUG:Training:3.4:(self_supervised_model.py): The first epoch is being initialized.")

    for epoch in tqdm(range(epoches)):
        for data_index, (datapath, data_split_path) in enumerate(zip(datapaths, data_splits)):
            if epoch == 0:
                logger.debug(f'Reading training data for index {data_index}...')

            data = pd.read_csv(datapath, index_col=0)
            data.index = data.index.astype(str)
            data_split = pd.read_csv(data_split_path, index_col=0)

            if epoch == 0:
                logger.debug(f'Data shape from file `{datapath}`: {data.shape}')
                logger.debug(f'Data shape from file `{data_split_path}` (split data file): {data_split.shape}')

            if mode == 'several':
                raise NotImplementedError(f"+ DEBUG:SingleEasyBinning:No role!")
                if data.shape[1] != 138 or data_split.shape[1] != 136:
                    sys.stderr.write(
                        f"Error: training mode with several only used in single-sample binning!\n")
                    sys.exit(1)

            train_data = data.values
            train_data_split = data_split.values
            n_must_link = len(train_data_split)
            if not is_combined:
                print(f"\t- IV. BEN: In training, we will only use k-mer features: 136/{train_data.shape}!")
                train_data = train_data[:, :136]
            else:
                raise NotImplementedError(f"+ DEBUG:SingleEasyBinning:No role!")

                if norm_abundance(train_data):
                    raise NotImplementedError(f"+ DEBUG:SingleEasyBinning:No role!")

                    from sklearn.preprocessing import normalize
                    norm = np.sum(train_data, axis=0)
                    train_data = train_data / norm
                    train_data_split = train_data_split / norm
                    train_data = normalize(train_data, axis=1, norm='l1')
                    train_data_split = normalize(train_data_split, axis=1, norm='l1')

            data_length = len(train_data)
            if data_length == 0:
                logger.error(f'No data for sample {datapath}')
                raise ValueError(f'No data for sample {datapath}')
            elif data_length == 1:
                logger.error(f'Only one data point for sample {datapath} (binning would fail)')
                raise ValueError(f'Only one data point for sample {datapath} (binning would fail)')

            if quality_report_file_path is not None and contig_bins_file is not None:

                ########################################################################################################
                # Construct positive pairs
                pos_pairs = []
                pos_per_class = 3
                for bin in bin2quality:
                    if bin2quality[bin] == 'HQ':
                        sampled_indices = np.random.randint(low=0, high=len(bin2contigs[bin]),
                                                            size=len(bin2contigs[bin]) * pos_per_class)
                        for i in range(len(bin2contigs[bin])):
                            for j in range(pos_per_class):
                                pos_pairs.append(
                                    (bin2contigs[bin][i], bin2contigs[bin][sampled_indices[i * pos_per_class + j]]))
                pos_pairs = np.array(pos_pairs)

                # bin2quality bin2contigs
                # Construct negative pairs
                neg_pairs = []
                bin_names = list(bin2quality.keys())
                for i in range(len(bin_names)):
                    for j in range(i + 1, len(bin_names)):
                        source_bin, target_bin = bin_names[i], bin_names[j]
                        for source_contig in bin2contigs[source_bin]:
                            target_contig = bin2contigs[target_bin][
                                np.random.randint(low=0, high=len(bin2contigs[target_bin]), size=1)[0]
                            ]

                            neg_pairs.append((source_contig, target_contig))
                neg_pairs = np.array(neg_pairs)

                train_input_1 = np.concatenate(
                    (data.loc[neg_pairs[:, 0]].to_numpy()[:, :136], data.loc[pos_pairs[:, 0]].to_numpy()[:, :136], train_data_split[::2])
                )
                train_input_2 = np.concatenate(
                    (data.loc[neg_pairs[:, 1]].to_numpy()[:, :136], data.loc[pos_pairs[:, 1]].to_numpy()[:, :136], train_data_split[1::2])
                )
                train_labels = np.zeros(len(train_input_1), dtype=np.float32)
                train_labels[neg_pairs.shape[0]:] = 1

                ########################################################################################################
            else:

                # cannot link data is sampled randomly
                n_cannot_link = min(n_must_link * 1000 // 2, 4_000_000)
                indices1 = np.random.choice(data_length, size=n_cannot_link)
                indices2 = indices1 + 1 + np.random.choice(data_length - 1, size=n_cannot_link)
                indices2 %= data_length

                if epoch == 0:
                    logger.debug(
                        f'Number of must-link pairs: {len(train_data_split)//2}')
                    logger.debug(
                        f'Number of cannot-link pairs: {n_cannot_link}')

                # indices1 and indices2 are the indices of the negative samples
                train_input_1 = np.concatenate(
                    (train_data[indices1], train_data_split[::2])
                )
                train_input_2 = np.concatenate(
                    (train_data[indices2], train_data_split[1::2])
                )
                train_labels = np.zeros(len(train_input_1), dtype=np.float32)
                train_labels[len(indices1):] = 1
            dataset = feature_Dataset(train_input_1, train_input_2, train_labels)
            train_loader = DataLoader(
                dataset=dataset,
                batch_size=batchsize,
                shuffle=True,
                num_workers=0,
                drop_last=True)

            for train_input1, train_input2, train_label in train_loader:
                model.train()
                train_input1 = train_input1.to(device=device, dtype=torch.float32)
                train_input2 = train_input2.to(device=device, dtype=torch.float32)
                train_label = train_label.to(device=device, dtype=torch.float32)
                embedding1, cov1, embedding2, cov2 = model.forward(
                    train_input1, train_input2
                )
                # decoder1, decoder2 = model.decoder(embedding1, embedding2)
                optimizer.zero_grad()
                supervised_loss = loss_function(
                    embedding1.double(), cov1, embedding2.double(), cov2, train_label.double()
                )
                supervised_loss = supervised_loss.to(device)
                supervised_loss.backward()
                optimizer.step()

        scheduler.step()
        if (epoch+1) % 5 == 0 and epoch != 0:
            model.save_with_params_to(os.path.join(output, f"checkpoint={epoch+1}.pt"))

    logger.info('Training finished.')
    print(f"+ DEBUG:Training:3.5:(self_supervised_model.py): Training finished.")

    return model
