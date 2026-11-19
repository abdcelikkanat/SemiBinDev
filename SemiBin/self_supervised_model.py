import torch
from torch.utils.data import DataLoader
from torch.optim import lr_scheduler
import sys
# from .semi_supervised_model import Semi_encoding_single, Semi_encoding_multiple, feature_Dataset # This class is not used! (UncertainGen)
from .semi_supervised_model import Semi_encoding_single, feature_Dataset, model_load
import os
from .utils import norm_abundance


def loss_function(mean_emb1, mean_emb2, cov_emb1, cov_emb2, label, mean_only=True, std_only=False):

    if mean_only:
        relu = torch.nn.ReLU()
        d = torch.norm(mean_emb1 - mean_emb2, p=2, dim=1)
        square_pred = torch.square(d)
        margin_square = torch.square(relu(1 - d))
        per_pair = label * square_pred + (1 - label) * margin_square
        return torch.mean(per_pair), per_pair

    elif std_only:

        relu = torch.nn.ReLU()
        square_pred = torch.sum((mean_emb1 - mean_emb2)**2 / (cov_emb1 + cov_emb2), dim=1)
        # eps keeps the gradient finite when two embeddings coincide (sqrt'(0) = inf -> NaN)
        d = torch.sqrt(square_pred + 1e-12)
        margin_square = torch.square(relu(1 - d))
        per_pair = label * square_pred + (1 - label) * margin_square
        return torch.mean(per_pair), per_pair

    else:

        raise ValueError("mean_only and std_only cannot be true at the same time (UncertainGen)")


def train_self(
        logger, datapaths, data_splits, is_combined=True, batchsize=2048, epoches=15,
        device=None, num_process = 8, mode = 'single', mean_only=True, std_only=False, checkpoint_path="",
        output_folder="", emb_dim=100, hidden_dim=512, n_layers=1, save_every=5
):
    """
    Train model from one sample(mode=single) or several samples(mode=several)

    Saves model to disk and returns it

    Parameters
    ----------
    out : filename to write model to
    """

    assert mean_only != std_only, "mean_only and std_only cannot be true at the same time (UncertainGen)"
    assert std_only == False or checkpoint_path != "", "if std_only is true, then model_path must be (UncertainGen)"

    logger.info(f'[UncertainGen]: train_self(...) | is_combined {is_combined}')

    from tqdm import tqdm
    import pandas as pd
    import numpy as np

    train_data = pd.read_csv(datapaths[0], index_col=0).values

    if not is_combined:
        train_data = train_data[:, :136]

    torch.set_num_threads(num_process)

    logger.info('Training model...')

    if not is_combined:
        if mean_only:
            model = Semi_encoding_single(train_data.shape[1], emb_dim=emb_dim,
                                         hidden_dim=hidden_dim, n_layers=n_layers)
        if std_only:
            # The architecture is taken from the checkpoint; emb_dim/hidden_dim/n_layers are ignored.
            model = model_load(checkpoint_path, device=torch.device('cpu'))
        logger.info(f'[UncertainGen]: architecture | emb_dim {model.emb_dim} | '
                    f'hidden_dim {model.hidden_dim} | n_layers {model.n_layers}')
    else:
        raise NotImplemented("This part is not used! (UncertainGen)")
        model = Semi_encoding_multiple(train_data.shape[1])

    model = model.to(device)

    # UncertainGen Update
    model_params = []
    for name, param in model.named_parameters():
        if "mean" in name and std_only:
            param.requires_grad = False
        elif "log_std" in name and mean_only:
            param.requires_grad = False
        else:
            param.requires_grad = True
            model_params.append(param)
    ###

    # optimizer = torch.optim.Adam(model.parameters(), lr=1e-3) # UncertainGen update
    optimizer = torch.optim.Adam(model_params, lr=1e-3)
    scheduler = lr_scheduler.StepLR(optimizer, step_size=1, gamma=0.9)

    # UncertainGen Update: Define model parameters and set the correct optimization mode.
    # The frozen encoder must stay in eval mode: otherwise its BatchNorm running
    # statistics keep being updated (and dropout applied) although requires_grad=False.
    def set_train_mode():
        if mean_only:
            model.encoder_mean.train()
            model.encoder_log_std.eval()
        if std_only:
            model.encoder_mean.eval()
            model.encoder_log_std.train()
    set_train_mode()
    ###

    # UncertainGen: loss log (one row per epoch and data file), written as we go
    phase = "mean_only" if mean_only else "std_only"
    os.makedirs(output_folder, exist_ok=True)
    loss_log_path = os.path.join(output_folder, f"loss_{phase}.tsv")
    loss_log = open(loss_log_path, "w")
    loss_log.write("epoch\tdata_index\tlr\tn_batches\tmean_loss\tmust_link_loss\tcannot_link_loss\n")
    loss_log.flush()

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
                if data.shape[1] != 138 or data_split.shape[1] != 136:
                    sys.stderr.write(
                        f"Error: training mode with several only used in single-sample binning!\n")
                    sys.exit(1)

            train_data = data.values
            train_data_split = data_split.values
            n_must_link = len(train_data_split)
            if not is_combined:
                train_data = train_data[:, :136]
            else:
                raise NotImplemented("This part is not used! (UncertainGen)")
                if norm_abundance(train_data):
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
            # cannot link data is sampled randomly
            n_cannot_link = min(n_must_link * 1000 // 2, 4_000_000)
            indices1 = np.random.choice(data_length, size=n_cannot_link)
            indices2 = indices1 + 1 + np.random.choice(data_length - 1,
                                                       size=n_cannot_link)
            indices2 %= data_length


            if epoch == 0:
                logger.debug(
                    f'Number of must-link pairs: {len(train_data_split)//2}')
                logger.debug(
                    f'Number of cannot-link pairs: {n_cannot_link}')

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

            loss_sum, ml_sum, cl_sum, ml_n, cl_n, n_batches = 0.0, 0.0, 0.0, 0, 0, 0
            for train_input1, train_input2, train_label in train_loader:
                set_train_mode()
                train_input1 = train_input1.to(device=device, dtype=torch.float32)
                train_input2 = train_input2.to(device=device, dtype=torch.float32)
                train_label = train_label.to(device=device, dtype=torch.float32)
                mean_emb1, mean_emb2, cov_emb1, cov_emb2 = model.forward(
                    train_input1, train_input2, mean_only=mean_only, std_only=std_only
                )
                # decoder1, decoder2 = model.decoder(embedding1, embedding2)
                optimizer.zero_grad()
                supervised_loss, per_pair_loss = loss_function(
                    mean_emb1.double(),
                    mean_emb2.double(),
                    cov_emb1.double() if std_only else cov_emb1,
                    cov_emb2.double() if std_only else cov_emb2,
                    label=train_label.double(),
                    mean_only=mean_only, std_only=std_only,
                )
                supervised_loss = supervised_loss.to(device)
                supervised_loss.backward()
                optimizer.step()

                # UncertainGen: accumulate losses for logging (no extra forward pass)
                with torch.no_grad():
                    per_pair = per_pair_loss.detach()
                    is_ml = train_label > 0.5
                    loss_sum += supervised_loss.item()
                    ml_sum += per_pair[is_ml].sum().item()
                    cl_sum += per_pair[~is_ml].sum().item()
                    ml_n += int(is_ml.sum().item())
                    cl_n += int((~is_ml).sum().item())
                    n_batches += 1

            mean_loss = loss_sum / max(n_batches, 1)
            ml_loss = ml_sum / ml_n if ml_n else float('nan')
            cl_loss = cl_sum / cl_n if cl_n else float('nan')
            lr = optimizer.param_groups[0]['lr']
            loss_log.write(f"{epoch+1}\t{data_index}\t{lr:.6g}\t{n_batches}\t"
                           f"{mean_loss:.8g}\t{ml_loss:.8g}\t{cl_loss:.8g}\n")
            loss_log.flush()
            logger.info(f'[UncertainGen]: epoch {epoch+1}/{epoches} | data {data_index} | '
                        f'loss {mean_loss:.6f} | must-link {ml_loss:.6f} | cannot-link {cl_loss:.6f}')

        # UncertainGen Update: save a checkpoint every `save_every` epochs
        # (after all data files have been seen in this epoch)
        if save_every > 0 and (epoch + 1) % save_every == 0:
            filename = f"checkpoint_{phase}_current_epoch_{epoch+1}.pt"
            model.save_with_params_to(os.path.join(output_folder, filename))
        ###

        scheduler.step()

    loss_log.close()
    logger.info(f'Training finished. Loss log written to {loss_log_path}')
    return model
