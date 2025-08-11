macro center_text str {
    local len, pad, left_pad, right_pad
    virtual at 0
        db str
        len = $
    end virtual
    pad = 80 - len
    left_pad = pad / 2
    right_pad = pad - left_pad
    repeat left_pad
        db ' '
    end repeat
    db str
    repeat right_pad
        db ' '
    end repeat
}